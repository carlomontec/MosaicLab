import Foundation
import CoreGraphics
import SQLite3
import os

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Two-tier (L1 RAM + L2 Persistent Disk) cache for preprocessed photo descriptors.
/// Caches the 16x16 thumbnail pixels and edge descriptors so repeated mosaic runs
/// with the same photos execute at memory bandwidth (~0.05s) with zero disk I/O.
public final class SourceCandidateCache: @unchecked Sendable {
    public static let shared = SourceCandidateCache()
    
    // MARK: - L1 RAM Cache Structures
    private struct MemoryEntry {
        let candidate: SourceImageCandidate
        let modTime: TimeInterval
        let fileSize: Int64
        var lastAccess: TimeInterval
    }
    
    private let ramLock: os_unfair_lock_t = {
        let lock = os_unfair_lock_t.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        return lock
    }()
    
    public var maxRAMEntries: Int = 50_000
    private var memoryCache: [String: MemoryEntry] = [:]
    
    // MARK: - L2 Disk Cache (SQLite)
    private let dbLock = NSLock()
    private var db: OpaquePointer?
    private var getStmt: OpaquePointer?
    private var insertStmt: OpaquePointer?
    private let dbURL: URL
    
    // User configurable max disk size (default 2 GB)
    public var maxDiskBytes: Int64 {
        get {
            let val = UserDefaults.standard.integer(forKey: "mosaiclab_max_disk_cache_bytes")
            return val > 0 ? Int64(val) : 2 * 1024 * 1024 * 1024
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "mosaiclab_max_disk_cache_bytes")
            pruneDiskIfNeeded()
        }
    }
    
    public init() {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        let appCacheDir = cachesDirectory.appendingPathComponent("com.carlomontec.mosaiclab", isDirectory: true)
        try? fileManager.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
        
        self.dbURL = appCacheDir.appendingPathComponent("candidate_descriptors.sqlite")
        initDatabase()
    }
    
    deinit {
        dbLock.lock()
        if let stmt = getStmt {
            sqlite3_finalize(stmt)
            getStmt = nil
        }
        if let stmt = insertStmt {
            sqlite3_finalize(stmt)
            insertStmt = nil
        }
        if let database = db {
            sqlite3_close(database)
            db = nil
        }
        dbLock.unlock()
        
        ramLock.deinitialize(count: 1)
        ramLock.deallocate()
    }
    
    // MARK: - Fast Inlined RAM Locking Helper
    @inline(__always)
    private func withRAMLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(ramLock)
        defer { os_unfair_lock_unlock(ramLock) }
        return try body()
    }
    
    // MARK: - LRU Memory Eviction
    /// Prunes the oldest entries when memory exceeds `maxRAMEntries`.
    /// Caller MUST hold `ramLock`.
    private func pruneMemoryCacheIfNeeded() {
        guard memoryCache.count > maxRAMEntries else { return }
        // Evict excess plus 20% breathing room to amortize sort cost across insertions
        let excess = memoryCache.count - maxRAMEntries + (maxRAMEntries / 5)
        let keysToEvict = memoryCache
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
            .prefix(excess)
            .map { $0.key }
        for key in keysToEvict {
            memoryCache.removeValue(forKey: key)
        }
    }
    
    // MARK: - Database Initialization
    private func initDatabase() {
        dbLock.lock()
        defer { dbLock.unlock() }
        
        if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
            // Enable WAL mode for high concurrent throughput
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)
            
            let createSQL = """
            CREATE TABLE IF NOT EXISTS candidates (
                id TEXT PRIMARY KEY,
                url TEXT NOT NULL,
                mod_time REAL NOT NULL,
                file_size INTEGER NOT NULL,
                pixels BLOB NOT NULL,
                last_access REAL NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_last_access ON candidates(last_access);
            """
            sqlite3_exec(db, createSQL, nil, nil, nil)
            
            // Prepare statements once for repeated execution
            let getSQL = "SELECT url, mod_time, file_size, pixels FROM candidates WHERE id = ? LIMIT 1;"
            if sqlite3_prepare_v2(db, getSQL, -1, &getStmt, nil) != SQLITE_OK {
                getStmt = nil
            }
            
            let insertSQL = """
            INSERT OR REPLACE INTO candidates (id, url, mod_time, file_size, pixels, last_access)
            VALUES (?, ?, ?, ?, ?, ?);
            """
            if sqlite3_prepare_v2(db, insertSQL, -1, &insertStmt, nil) != SQLITE_OK {
                insertStmt = nil
            }
        }
    }
    
    // MARK: - Public Retrieval & Storage
    
    /// Retrieves a candidate from L1 RAM or L2 Disk cache if modification date & size match.
    public func get(identifier: String, modTime: TimeInterval, fileSize: Int64) -> SourceImageCandidate? {
        let now = ProcessInfo.processInfo.systemUptime
        
        // 1. Check L1 RAM Cache (< 0.001 ms)
        let ramCandidate: SourceImageCandidate? = withRAMLock {
            if var entry = memoryCache[identifier] {
                if abs(entry.modTime - modTime) < 1.0 && entry.fileSize == fileSize {
                    entry.lastAccess = now
                    memoryCache[identifier] = entry
                    return entry.candidate
                } else {
                    // Outdated entry
                    memoryCache.removeValue(forKey: identifier)
                }
            }
            return nil
        }
        
        if let ramCandidate = ramCandidate {
            return ramCandidate
        }
        
        // 2. Check L2 Disk SQLite Cache (< 0.05 ms with prepared statement)
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let stmt = getStmt else { return nil }
        
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        defer {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }
        
        sqlite3_bind_text(stmt, 1, identifier, -1, SQLITE_TRANSIENT)
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            let rowModTime = sqlite3_column_double(stmt, 1)
            let rowFileSize = sqlite3_column_int64(stmt, 2)
            
            // Validate file unchanged
            if abs(rowModTime - modTime) < 1.0 && rowFileSize == fileSize {
                guard let urlCStr = sqlite3_column_text(stmt, 0),
                      let pixelsBlob = sqlite3_column_blob(stmt, 3) else {
                    return nil
                }
                let blobBytes = sqlite3_column_bytes(stmt, 3)
                let urlString = String(cString: urlCStr)
                guard let url = URL(string: urlString) else { return nil }
                let pixelsData = Data(bytes: pixelsBlob, count: Int(blobBytes))
                
                let candidate = SourceImageCandidate(
                    identifier: identifier,
                    url: url,
                    thumbnailPixels: pixelsData
                )
                
                // Promote to L1 RAM cache
                withRAMLock {
                    memoryCache[identifier] = MemoryEntry(
                        candidate: candidate,
                        modTime: modTime,
                        fileSize: fileSize,
                        lastAccess: now
                    )
                    pruneMemoryCacheIfNeeded()
                }
                
                return candidate
            }
        }
        
        return nil
    }
    
    /// Batch retrieves candidates from L1 RAM or L2 Disk cache matching modification date & size.
    public func getBatch(items: [(id: String, modTime: TimeInterval, fileSize: Int64)]) -> [String: SourceImageCandidate] {
        guard !items.isEmpty else { return [:] }
        var results: [String: SourceImageCandidate] = [:]
        results.reserveCapacity(items.count)
        
        var l1Misses: [(id: String, modTime: TimeInterval, fileSize: Int64)] = []
        l1Misses.reserveCapacity(items.count)
        
        let now = ProcessInfo.processInfo.systemUptime
        
        // 1. Fast L1 RAM lookup under os_unfair_lock
        withRAMLock {
            for item in items {
                if var entry = memoryCache[item.id] {
                    if abs(entry.modTime - item.modTime) < 1.0 && entry.fileSize == item.fileSize {
                        entry.lastAccess = now
                        memoryCache[item.id] = entry
                        results[item.id] = entry.candidate
                    } else {
                        memoryCache.removeValue(forKey: item.id)
                        l1Misses.append(item)
                    }
                } else {
                    l1Misses.append(item)
                }
            }
        }
        
        // If all items hit L1 RAM, return immediately without touching SQLite
        if l1Misses.isEmpty {
            return results
        }
        
        // 2. Query L2 Disk SQLite for L1 misses using the prepared getStmt
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let stmt = getStmt else { return results }
        
        var diskHitsToPromote: [MemoryEntry] = []
        diskHitsToPromote.reserveCapacity(l1Misses.count)
        
        for item in l1Misses {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            
            sqlite3_bind_text(stmt, 1, item.id, -1, SQLITE_TRANSIENT)
            
            if sqlite3_step(stmt) == SQLITE_ROW {
                let rowModTime = sqlite3_column_double(stmt, 1)
                let rowFileSize = sqlite3_column_int64(stmt, 2)
                
                if abs(rowModTime - item.modTime) < 1.0 && rowFileSize == item.fileSize {
                    guard let urlCStr = sqlite3_column_text(stmt, 0),
                          let pixelsBlob = sqlite3_column_blob(stmt, 3) else {
                        continue
                    }
                    let blobBytes = sqlite3_column_bytes(stmt, 3)
                    let urlString = String(cString: urlCStr)
                    guard let url = URL(string: urlString) else { continue }
                    let pixelsData = Data(bytes: pixelsBlob, count: Int(blobBytes))
                    
                    let candidate = SourceImageCandidate(
                        identifier: item.id,
                        url: url,
                        thumbnailPixels: pixelsData
                    )
                    results[item.id] = candidate
                    diskHitsToPromote.append(MemoryEntry(
                        candidate: candidate,
                        modTime: item.modTime,
                        fileSize: item.fileSize,
                        lastAccess: now
                    ))
                }
            }
        }
        
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        
        // 3. Promote disk hits to L1 RAM cache in bulk
        if !diskHitsToPromote.isEmpty {
            withRAMLock {
                for entry in diskHitsToPromote {
                    memoryCache[entry.candidate.identifier] = entry
                }
                pruneMemoryCacheIfNeeded()
            }
        }
        
        return results
    }
    
    /// Stores a preprocessed candidate in both L1 RAM and L2 Disk cache.
    public func put(_ candidate: SourceImageCandidate, modTime: TimeInterval, fileSize: Int64) {
        let now = ProcessInfo.processInfo.systemUptime
        let id = candidate.identifier
        
        // 1. Put in L1 RAM
        withRAMLock {
            memoryCache[id] = MemoryEntry(
                candidate: candidate,
                modTime: modTime,
                fileSize: fileSize,
                lastAccess: now
            )
            pruneMemoryCacheIfNeeded()
        }
        
        // 2. Put in L2 Disk SQLite using prepared statement
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let stmt = insertStmt else { return }
        
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        defer {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
        }
        
        sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, candidate.url.absoluteString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, modTime)
        sqlite3_bind_int64(stmt, 4, fileSize)
        _ = candidate.thumbnailPixels.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, 5, ptr.baseAddress, Int32(candidate.thumbnailPixels.count), SQLITE_TRANSIENT)
        }
        sqlite3_bind_double(stmt, 6, Date().timeIntervalSince1970)
        
        sqlite3_step(stmt)
    }
    
    /// Stores a batch of preprocessed candidates in both L1 RAM and L2 Disk cache wrapped in a single SQLite transaction.
    public func putBatch(_ candidates: [(candidate: SourceImageCandidate, modTime: TimeInterval, fileSize: Int64)]) {
        guard !candidates.isEmpty else { return }
        let now = ProcessInfo.processInfo.systemUptime
        
        // 1. Put in L1 RAM
        withRAMLock {
            for item in candidates {
                memoryCache[item.candidate.identifier] = MemoryEntry(
                    candidate: item.candidate,
                    modTime: item.modTime,
                    fileSize: item.fileSize,
                    lastAccess: now
                )
            }
            pruneMemoryCacheIfNeeded()
        }
        
        // 2. Put in L2 Disk SQLite inside a single transaction
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let database = db, let stmt = insertStmt else { return }
        
        sqlite3_exec(database, "BEGIN TRANSACTION;", nil, nil, nil)
        let accessTimestamp = Date().timeIntervalSince1970
        
        for item in candidates {
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            
            let id = item.candidate.identifier
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, item.candidate.url.absoluteString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, item.modTime)
            sqlite3_bind_int64(stmt, 4, item.fileSize)
            _ = item.candidate.thumbnailPixels.withUnsafeBytes { ptr in
                sqlite3_bind_blob(stmt, 5, ptr.baseAddress, Int32(item.candidate.thumbnailPixels.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_double(stmt, 6, accessTimestamp)
            
            sqlite3_step(stmt)
        }
        
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_exec(database, "COMMIT;", nil, nil, nil)
    }
    
    // MARK: - Cache Statistics & Diagnostics
    
    public var ramPhotoCount: Int {
        withRAMLock { memoryCache.count }
    }
    
    public var ramSizeBytes: Int64 {
        withRAMLock { Int64(memoryCache.count) * 1200 }
    }
    
    public var diskPhotoCount: Int {
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let database = db else { return 0 }
        
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT COUNT(*) FROM candidates;", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }
        
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }
    
    public var diskSizeBytes: Int64 {
        let fileManager = FileManager.default
        let attrs = (try? fileManager.attributesOfItem(atPath: dbURL.path)) ?? [:]
        var total = Int64(attrs[.size] as? UInt64 ?? 0)
        
        // Add WAL and SHM files
        let walURL = dbURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = dbURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        if let walAttrs = try? fileManager.attributesOfItem(atPath: walURL.path) {
            total += Int64(walAttrs[.size] as? UInt64 ?? 0)
        }
        if let shmAttrs = try? fileManager.attributesOfItem(atPath: shmURL.path) {
            total += Int64(shmAttrs[.size] as? UInt64 ?? 0)
        }
        return total
    }
    
    // MARK: - Cache Management
    
    public func clearRAM() {
        withRAMLock { memoryCache.removeAll() }
    }
    
    public func clearDisk() {
        dbLock.lock()
        defer { dbLock.unlock() }
        guard let database = db else { return }
        if let stmt = getStmt { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
        if let stmt = insertStmt { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
        sqlite3_exec(database, "DELETE FROM candidates; VACUUM;", nil, nil, nil)
    }
    
    public func clearAll() {
        clearRAM()
        clearDisk()
    }
    
    public func pruneDiskIfNeeded() {
        let limit = maxDiskBytes
        guard limit > 0 else { return }
        
        let current = diskSizeBytes
        if current > limit {
            dbLock.lock()
            defer { dbLock.unlock() }
            guard let database = db else { return }
            
            if let stmt = getStmt { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
            if let stmt = insertStmt { sqlite3_reset(stmt); sqlite3_clear_bindings(stmt) }
            
            // Delete oldest 25% of candidates based on last_access
            let pruneSQL = """
            DELETE FROM candidates WHERE id IN (
                SELECT id FROM candidates ORDER BY last_access ASC LIMIT (SELECT COUNT(*) / 4 FROM candidates)
            );
            VACUUM;
            """
            sqlite3_exec(database, pruneSQL, nil, nil, nil)
        }
    }
    
    public var cacheFolderURL: URL {
        return dbURL.deletingLastPathComponent()
    }
}
