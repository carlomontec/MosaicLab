# MosaicLab Cache Architecture & Optimizations
**Author:** Dr. Carlo Monjaraz-Tec
**Date:** 2026-10-06
**Branch:** `perf/simd-matcher`

This document provides a rigorous engineering evaluation of the two-tier caching system in MosaicLab (L1 RAM + L2 SQLite). It outlines identified bottlenecks, theoretical performance limits, and step-by-step implementation blueprints for modernizing the storage layer.

---

## 1. Level 1: Memory & Data Representation (L1 Cache)

### Critique & Weaknesses
- **Unbounded RAM Growth:** The `memoryCache` dictionary in `SourceCandidateCache` is strictly append-only. There is no eviction strategy (e.g., LRU). Loading a 100,000-photo library will permanently pin at least ~150-200 MB in RAM (accounting for Swift dictionary overhead).
- **Concurrency Bottleneck (Lock Contention):** The `NSLock` (`ramLock`) wraps every L1 read and write. In `MosaicViewModel.runMatching`, the `withTaskGroup` fires parallel requests across up to 128 worker threads. All workers collide on this single `NSLock`, creating severe thread contention and priority inversion.

### Actionable Solutions & Blueprint
**1. Sharded Lock or Lock-Free Reads:**
Replace the single `NSLock` with `os_unfair_lock` (or `pthread_rwlock_t` for concurrent reads). For even higher throughput, use a sharded dictionary (array of dictionaries, hashed by identifier) to distribute lock contention.

**2. LRU Eviction:**
Wrap the memory cache in a bounded structure.

```swift
// Example Swift Diff for L1 Cache
import os.lock

private let ramLock = os_unfair_lock_t.allocate(capacity: 1)
ramLock.initialize(to: os_unfair_lock())

// ... inside get()
os_unfair_lock_lock(ramLock)
let entry = memoryCache[identifier]
os_unfair_lock_unlock(ramLock)
```

---

## 2. Level 2: Disk Persistence & SQLite (L2 Cache)

### Critique & Weaknesses
- **Missing Transactions for Writes:** The `put` method executes a single `INSERT OR REPLACE` directly. In SQLite, any write outside an explicit transaction initiates an auto-commit, causing a full disk `fsync`. This caps write throughput to ~1,000 rows/sec on NVMe. Wrapping batch inserts in `BEGIN TRANSACTION;` / `COMMIT;` will boost this to ~50,000+ rows/sec.
- **Statement Re-compilation Overhead:** `sqlite3_prepare_v2` is invoked on every single cache read (`get`) and write (`put`). Parsing SQL strings per item adds hundreds of milliseconds of overhead for large batches.
- **Synchronous `last_access` Updates:** The `get` method updates the `last_access` timestamp synchronously before returning, continuing to hold `dbLock` despite the comment ("Update last_access in background"). This doubles query time and blocks all other readers.

### Actionable Solutions & Blueprint
**1. Statement Caching:**
Compile the `SELECT` and `INSERT` statements once during `initDatabase` and reuse them via `sqlite3_reset()` and `sqlite3_clear_bindings()`.

**2. Batched Transactions API:**
Implement a bulk insert method for candidate processing.

```swift
// Example Swift Diff for Statement Caching
private var getStmt: OpaquePointer?
private var insertStmt: OpaquePointer?

private func initDatabase() {
    // ... setup db
    sqlite3_prepare_v2(db, "SELECT url, mod_time, file_size, pixels FROM candidates WHERE id = ? LIMIT 1;", -1, &getStmt, nil)
    sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO candidates (id, url, mod_time, file_size, pixels, last_access) VALUES (?, ?, ?, ?, ?, ?);", -1, &insertStmt, nil)
}

public func putBatch(_ candidates: [(candidate: SourceImageCandidate, modTime: TimeInterval, fileSize: Int64)]) {
    dbLock.lock()
    defer { dbLock.unlock() }
    sqlite3_exec(db, "BEGIN TRANSACTION;", nil, nil, nil)
    
    for item in candidates {
        sqlite3_bind_text(insertStmt, 1, (item.candidate.identifier as NSString).utf8String, -1, nil)
        // bind others...
        sqlite3_step(insertStmt)
        sqlite3_reset(insertStmt)
    }
    
    sqlite3_exec(db, "COMMIT;", nil, nil, nil)
}
```

---

## 3. Level 3: Pipeline Integration & Concurrency

### Critique & Weaknesses
- **Serialized SQLite Access:** In `MosaicViewModel`, `withTaskGroup` spawns tasks that individually call `SourceCandidateCache.shared.get()`. Because `dbLock.lock()` serializes access to the single SQLite connection, the parallel workers are effectively executing synchronously when hitting L2 cache misses.

### Actionable Solutions & Blueprint
- **Read-Only Connection Pool:** Open multiple SQLite connections (e.g., one per core) using `SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX`. Worker threads can pull a connection from a thread-safe pool, allowing truly parallel L2 reads.
- **Bulk Fetch API:** Fetching batches via `WHERE id IN (?, ?, ...)` eliminates the SQLite boundary transition per item.

---

## 4. Level 4: Edge Cases & Cloud Storage

### Critique & Weaknesses
- **Apple Photos Immutability:** Apple Photos IDs (`applephotos://`) do not return valid `URL.resourceValues`. The cache receives `modTime = 0` and `fileSize = 0`. If a user edits a photo in Apple Photos (e.g., cropping), the cache will not invalidate.
- **iCloud Dataless Files:** Fetching `fileSize` on iCloud files that are purged locally may trigger an unintended synchronous download or fail.

### Actionable Solutions & Blueprint
- Query `PHAsset.modificationDate` directly in `ApplePhotosSource` and use the asset's pixel dimensions (`asset.pixelWidth * asset.pixelHeight`) as a proxy for file size.
- For local files, query `URLResourceKey.ubiquitousItemDownloadingStatusKey` to skip dataless files without triggering downloads.

---

## 5. Level 5: 256px Display Thumbnails vs 16x16 Matching Pixels

### Critique & Weaknesses
- Currently, `16x16` match descriptors are persisted to L2 disk, but `256px` display thumbnails are only held in the volatile `NSCache` (`MosaicThumbnailCache`).
- When a user restarts MosaicLab, canvas redraw is extremely slow because thousands of original JPEGs/HEICs must be decoded via `CGImageSourceCreateThumbnailAtIndex` to regenerate the 256px thumbnails.

### Actionable Solutions & Blueprint
- **Unification Strategy:** Write the 256px thumbnails to a local filesystem cache (e.g., `~/Library/Caches/com.carlomontec.mosaiclab/thumbnails/<id>.jpg`) during the initial preprocessing phase. 
- Use SQLite to map the IDs to filesystem paths, or append a `display_thumb BLOB` to the SQLite schema (though external files are generally faster for images > 100KB).
- **Instant Redraw:** On canvas render, `MosaicThumbnailCache` should attempt to load the JPEG from the local cache folder before falling back to decoding the original massive source image.

```swift
// Example Swift Diff for Disk-Backed Thumbnail Cache
public func thumbnail(for url: URL, maxPixelSize: Int = 256) -> CGImage? {
    let key = cacheKey(for: url)
    if let cached = cache.object(forKey: key) { return cached }
    
    let cacheURL = thumbnailsDir.appendingPathComponent("\(key.hash).jpg")
    if FileManager.default.fileExists(atPath: cacheURL.path),
       let img = loadJPEG(from: cacheURL) {
        cache.setObject(img, forKey: key)
        return img
    }
    
    // Fallback to original decoding...
    // and then save to disk asynchronously
}
```
