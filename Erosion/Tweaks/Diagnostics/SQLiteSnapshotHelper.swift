//
//  SQLiteSnapshotHelper.swift
//  Erosion
//
//  [Experimental / Fitur Uji] Zero-lock APFS clonefile() CoW snapshot reader for live
//  system SQLite databases (Powerlog, Safari Bookmarks, VoiceMemos).
//

import Foundation
import SQLite3

@_silgen_name("clonefile")
private func apfs_clonefile(_ src: UnsafePointer<CChar>, _ dst: UnsafePointer<CChar>, _ flags: UInt32) -> Int32

enum SQLiteSnapshotError: LocalizedError {
    case sourceMissing(String)
    case snapshotFailed(String)
    case openFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceMissing(let msg),
             .snapshotFailed(let msg),
             .openFailed(let msg):
            return msg
        }
    }
}

enum SQLiteSnapshotHelper {
    /// Clones a live SQLite database (and optional `-wal` / `-shm` sidecars) into a private
    /// temporary sandbox directory via APFS copy-on-write `clonefile()`, never locking or
    /// mutating the original system file.
    static func withClonedDatabase<T>(at dbPath: String, body: (OpaquePointer) throws -> T) throws -> T {
        let canonical = (dbPath as NSString).standardizingPath
        guard fm.isReadableFile(atPath: canonical) else {
            throw SQLiteSnapshotError.sourceMissing("File basis data target tidak ada atau sandbox saat ini tidak memiliki izin baca: \(canonical)")
        }

        let snapDir = fm.temporaryDirectory.appendingPathComponent("sql_snap_\(UUID().uuidString)")
        try fm.createDirectory(at: snapDir, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: snapDir)
        }

        let baseName = (canonical as NSString).lastPathComponent
        let dstMain = snapDir.appendingPathComponent(baseName).path

        try cloneOrCopyFile(from: canonical, to: dstMain)
        _ = chmod(dstMain, 0o600)

        for suffix in ["-wal", "-shm"] {
            let srcSide = canonical + suffix
            if fm.isReadableFile(atPath: srcSide) {
                let dstSide = dstMain + suffix
                try? cloneOrCopyFile(from: srcSide, to: dstSide)
                _ = chmod(dstSide, 0o600)
            }
        }

        var db: OpaquePointer?
        // Open our private sandbox clone in READONLY first; if WAL recovery requires local shm/wal replay
        // inside our private temp folder, retry on the private clone (zero touch on original system path).
        var rc = sqlite3_open_v2(dstMain, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil)
        if rc == SQLITE_OK, let testDB = db {
            var probeStmt: OpaquePointer?
            let probeRC = sqlite3_prepare_v2(testDB, "SELECT name FROM sqlite_master LIMIT 1;", -1, &probeStmt, nil)
            sqlite3_finalize(probeStmt)
            if probeRC != SQLITE_OK {
                sqlite3_close(testDB)
                db = nil
                try? fm.removeItem(atPath: dstMain + "-shm")
                rc = sqlite3_open_v2(dstMain, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)
            }
        } else {
            if let existing = db { sqlite3_close(existing) }
            db = nil
            try? fm.removeItem(atPath: dstMain + "-shm")
            rc = sqlite3_open_v2(dstMain, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)
        }

        guard rc == SQLITE_OK, let validDB = db else {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "kode error \(rc)"
            if let existing = db { sqlite3_close(existing) }
            throw SQLiteSnapshotError.openFailed("Gagal membuka snapshot basis data: \(msg)")
        }
        sqlite3_busy_timeout(validDB, 1500)
        defer {
            sqlite3_close(validDB)
        }
        return try body(validDB)
    }

    private static func cloneOrCopyFile(from src: String, to dst: String) throws {
        if fm.fileExists(atPath: dst) {
            try? fm.removeItem(atPath: dst)
        }
        if apfs_clonefile(src, dst, 0) == 0 {
            return
        }
        do {
            try fm.copyItem(atPath: src, toPath: dst)
        } catch {
            throw SQLiteSnapshotError.snapshotFailed("Gagal membuat snapshot read-only: \(error.localizedDescription)")
        }
    }

    static func columnNames(in table: String, db: OpaquePointer) -> Set<String> {
        let safeTable = table.replacingOccurrences(of: "\"", with: "")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(\"\(safeTable)\");", -1, &stmt, nil) == SQLITE_OK,
              let validStmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(validStmt) }
        var cols = Set<String>()
        while sqlite3_step(validStmt) == SQLITE_ROW {
            if let cName = sqlite3_column_text(validStmt, 1) {
                cols.insert(String(cString: cName))
            }
        }
        return cols
    }

    static func allTables(in db: OpaquePointer) -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table';", -1, &stmt, nil) == SQLITE_OK,
              let validStmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(validStmt) }
        var list: [String] = []
        while sqlite3_step(validStmt) == SQLITE_ROW {
            if let cName = sqlite3_column_text(validStmt, 0) {
                list.append(String(cString: cName))
            }
        }
        return list
    }

    static func stringCol(_ stmt: OpaquePointer, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let ptr = sqlite3_column_text(stmt, idx) else {
            return nil
        }
        return String(cString: ptr)
    }

    static func doubleCol(_ stmt: OpaquePointer, _ idx: Int32) -> Double? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return sqlite3_column_double(stmt, idx)
    }

    static func intCol(_ stmt: OpaquePointer, _ idx: Int32) -> Int? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(stmt, idx))
    }
}
