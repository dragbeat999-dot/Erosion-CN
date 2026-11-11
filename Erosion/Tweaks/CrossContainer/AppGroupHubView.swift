//
//  AppGroupHubView.swift
//  Erosion
//
//  [Experimental / Fitur Uji] Cross-Container AppGroup Hub:
//  1. Proxy client AppGroup discovery + Apple Intelligence & CN Call Screening .sgmodule generator/injector.
//  2. Read-only APFS clonefile() Safari Bookmarks.db extractor (HTML & JSON export).
//

import SwiftUI
import SQLite3
import UIKit

struct DetectedAppGroupItem: Identifiable {
    let id: String
    let groupID: String
    let clientName: String
    let containerURL: URL
}

struct SafariBookmarkRecord: Identifiable, Codable {
    let id: Int
    let title: String
    let url: String
}

enum ProxyRuleFormat: String, CaseIterable, Identifiable {
    case surgeModule = "surge"
    case stashOverride = "stash"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .surgeModule: return "Surge / Loon / Shadowrocket (.sgmodule)"
        case .stashOverride: return "Aturan Override Stash (.stoverride / YAML)"
        }
    }
}

struct AppGroupHubView: View {
    @State private var isScanning = false
    @State private var scanSummary = "Tekan segarkan di kanan atas untuk memindai grup aplikasi bersama (AppGroup) di perangkat"
    @State private var proxyGroups: [DetectedAppGroupItem] = []
    @State private var safariBookmarksDBPath: String?
    @State private var bookmarks: [SafariBookmarkRecord] = []
    @State private var proxyPolicyName: String = "PROXY"
    @State private var ruleFormat: ProxyRuleFormat = .surgeModule
    @State private var hasAutoSelectedFormat = false
    @State private var showRulePreview = false

    private static let knownProxyGroupMap: [String: String] = [
        "group.com.nssurge.inc.surge-ios": "Surge",
        "group.com.nssurge.inc.surge-ios-tf": "Surge (TestFlight)",
        "group.com.liguangming.Shadowrocket": "Shadowrocket",
        "group.com.luo.quantumult-x": "Quantumult X",
        "group.com.loon.loon": "Loon",
        "group.com.loon0x00.loon": "Loon",
        "group.ws.stash.app": "Stash"
    ]

    private var surgeGroup: DetectedAppGroupItem? {
        proxyGroups.first { $0.groupID.hasPrefix("group.com.nssurge.inc.surge-ios") }
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "flask.fill")
                        .foregroundStyle(Color.orange)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fitur Uji · Hub Grup Bersama AppGroup Lintas Container")
                            .font(.subheadline.weight(.semibold))
                        Text("Menembus isolasi sandbox satu aplikasi: mendukung pembuatan sekali klik atau penulisan modul split-routing \"Penanya Panggilan Mandarin Tiongkok + Apple Intelligence Luar Negeri\" yang berdampingan ke grup bersama alat proxy, serta ekspor bookmark Safari tanpa kehilangan data melalui snapshot zero-lock APFS clonefile().")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                HStack {
                    Text("Status Pemindaian")
                    Spacer()
                    if isScanning {
                        ProgressView()
                    } else {
                        Text("Terdeteksi \(proxyGroups.count) grup alat jaringan")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(scanSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                HeaderLabel("Status Deteksi Grup Bersama [Uji]", symbol: "square.stack.3d.up")
            }

            Section {
                Picker("Format Aturan", selection: $ruleFormat) {
                    ForEach(ProxyRuleFormat.allCases) { fmt in
                        Text(fmt.displayName).tag(fmt)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nama Grup Kebijakan Node AI Luar Negeri")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Contoh PROXY / AI / 🇺🇸 Node AS", text: $proxyPolicyName)
                        .font(.subheadline.monospaced())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(.vertical, 2)

                Button {
                    exportRuleFileViaShareSheet()
                } label: {
                    Label(
                        ruleFormat == .stashOverride
                            ? "Ekspor File Override .stoverride (Impor ke Stash)"
                            : "Ekspor File Modul Split-Routing .sgmodule (Berbagi Universal)",
                        systemImage: "square.and.arrow.up"
                    )
                }

                Button {
                    UIPasteboard.general.string = currentRuleContent()
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "Aturan split-routing berhasil disalin!",
                        body: ruleFormat == .stashOverride
                            ? "Aturan Override Stash (YAML) telah disalin ke clipboard, dapat dibuat atau ditempel di \"Override\" Stash untuk digunakan (pastikan node AS yang dipilih telah mengaktifkan udp: true)."
                            : "Aturan modul Surge telah disalin ke clipboard sistem, dapat langsung ditempel ke konfigurasi modul Surge / Loon / Shadowrocket."
                    )
                } label: {
                    Label(
                        ruleFormat == .stashOverride ? "Salin Sumber Override YAML Stash ke Clipboard" : "Salin Sumber Aturan Modul ke Clipboard",
                        systemImage: "doc.on.doc"
                    )
                }

                if let surge = surgeGroup, ruleFormat == .surgeModule {
                    Button {
                        Alertinator.shared.alert(
                            title: "Tulis ke direktori grup bersama Surge? [Fitur Uji]",
                            body: "Harap tutup aplikasi Surge terlebih dahulu dengan menggeser ke atas di latar belakang, lalu tekan \"Konfirmasi Tulis\". Setelah penulisan selesai, buka Surge -> Modul -> aktifkan \"Erosion Apple Intelligence Tiongkok & Penanya Panggilan Split-Routing\".",
                            actionLabel: "Konfirmasi Tulis",
                            action: { injectModuleIntoSurge(surge) }
                        )
                    } label: {
                        Label("Injeksi Sekali Klik ke Direktori Modul \(surge.clientName) di Perangkat [Uji]", systemImage: "bolt.horizontal.circle.fill")
                    }
                }

                DisclosureGroup(
                    ruleFormat == .stashOverride ? "Pratinjau Konten .stoverride Stash (YAML) yang Dihasilkan" : "Pratinjau Konten Aturan .sgmodule Surge yang Dihasilkan",
                    isExpanded: $showRulePreview
                ) {
                    Text(currentRuleContent())
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
            } header: {
                HeaderLabel("[Fitur Uji] Split-Routing Berdampingan Apple Intelligence & Penanya Panggilan Mandarin", symbol: "network.badge.shield.half.filled")
            } footer: {
                Text("Prinsip inti: atur guzzoni.apple.com / siri.apple.com / smoot.apple.com menjadi DIRECT dan tambahkan ke whitelist IP asli (always-real-ip / fake-ip-filter), untuk memastikan Siri Tiongkok dan filter panggilan Mandarin tersambung seketika; sekaligus tempatkan gspe1-ssl, apple-relay.*, OpenAI dan Google Visual Intelligence ke paling atas split-routing ke grup kebijakan AS (perhatian: node AS yang dipilih harus mendukung UDP/QUIC).")
            }

            if !proxyGroups.isEmpty {
                Section {
                    ForEach(proxyGroups) { item in
                        NavigationLink {
                            ContainerSubdirBrowserView(containerURL: item.containerURL, relativeSubpath: nil)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.clientName)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.groupID)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HeaderLabel("Grup Bersama Alat Proxy Terpasang di Perangkat [Uji]", symbol: "folder.badge.gearshape")
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Snapshot Basis Data Bookmark Safari")
                            .font(.subheadline.weight(.medium))
                        if safariBookmarksDBPath != nil {
                            Text("Berhasil mengurai \(bookmarks.count) bookmark URL secara lossless (snapshot read-only APFS)")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Text("Belum menemukan Bookmarks.db yang dapat dibaca atau bookmark kosong")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                if !bookmarks.isEmpty {
                    Button {
                        exportBookmarksHTML()
                    } label: {
                        Label("Ekspor File Bookmark HTML Standar (Kompatibel Semua Browser)", systemImage: "globe")
                    }

                    Button {
                        exportBookmarksJSON()
                    } label: {
                        Label("Ekspor Cadangan Bookmark Terstruktur JSON", systemImage: "curlybraces")
                    }

                    ForEach(bookmarks.prefix(8)) { bm in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bm.title.isEmpty ? "(Bookmark tanpa judul)" : bm.title)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                            Text(bm.url)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 1)
                    }
                    if bookmarks.count > 8 {
                        Text("… \(bookmarks.count - 8) bookmark lainnya akan disertakan lengkap dalam file ekspor")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HeaderLabel("[Fitur Uji] Ekspor Lossless Bookmark Safari Lintas Container", symbol: "book.fill")
            }
        }
        .navigationTitle("Split-Routing Grup Bersama dan Bookmark")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    scanAppGroups()
                } label: {
                    Label("Segarkan", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning)
            }
        }
        .onAppear {
            if proxyGroups.isEmpty && safariBookmarksDBPath == nil && !isScanning {
                scanAppGroups()
            }
        }
    }

    private var sanitizedPolicy: String {
        let trimmed = proxyPolicyName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "PROXY" : trimmed
    }

    private func currentRuleContent() -> String {
        switch ruleFormat {
        case .surgeModule:
            return buildSGModuleContent()
        case .stashOverride:
            return buildStashOverrideContent()
        }
    }

    private func buildSGModuleContent() -> String {
        let policy = sanitizedPolicy
        return """
        #!name=Erosion Apple Intelligence Tiongkok & Penanya Panggilan Split-Routing [Fitur Uji]
        #!desc=Dihasilkan oleh Erosion: menjaga Siri Tiongkok dan penanya panggilan Mandarin (guzzoni) tetap terhubung langsung ke IP asli, sekaligus mengarahkan Apple Intelligence cloud computing privasi, verifikasi lokasi regional, dan visual intelligence ke \(policy) di urutan teratas.
        #!category=Erosion

        [General]
        skip-proxy = %APPEND% guzzoni.apple.com
        always-real-ip = %APPEND% guzzoni.apple.com, *.guzzoni.apple.com, *.siri.apple.com

        [Rule]
        # 1. Gateway utama suara Siri Tiongkok dan penanya panggilan Mandarin harus langsung ke IP asli (dilarang keras melalui proxy)
        DOMAIN-SUFFIX,guzzoni.apple.com,DIRECT
        DOMAIN-SUFFIX,siri.apple.com,DIRECT
        DOMAIN,dejavu.apple.com,DIRECT
        DOMAIN,sequoia.apple.com,DIRECT
        DOMAIN-SUFFIX,smoot.apple.com,DIRECT

        # 2. Verifikasi lokasi regional Apple Intelligence dan relay PCC cloud computing privasi (gunakan node AS latensi rendah yang mendukung UDP/QUIC)
        DOMAIN,gspe1-ssl.ls.apple.com,\(policy)
        DOMAIN-SUFFIX,apple-relay.apple.com,\(policy)
        DOMAIN-SUFFIX,apple-relay.cloudflare.com,\(policy)
        DOMAIN-SUFFIX,apple-relay.fastly-edge.com,\(policy)
        DOMAIN-SUFFIX,apple-relay.akamaized.net,\(policy)
        DOMAIN-SUFFIX,cp4.cloudflare.com,\(policy)

        # 3. Ekstensi ChatGPT Siri dan visual intelligence (pertanyaan + pencarian gambar Google)
        DOMAIN-SUFFIX,openai.com,\(policy)
        DOMAIN-SUFFIX,chatgpt.com,\(policy)
        DOMAIN-SUFFIX,oaistatic.com,\(policy)
        DOMAIN-SUFFIX,oaiusercontent.com,\(policy)
        DOMAIN-SUFFIX,google.com,\(policy)
        DOMAIN-SUFFIX,googleapis.com,\(policy)
        DOMAIN-SUFFIX,gstatic.com,\(policy)
        """
    }

    private func buildStashOverrideContent() -> String {
        let policy = sanitizedPolicy
        return """
        name: "Erosion Apple Intelligence Tiongkok & Penanya Panggilan Split-Routing"
        desc: "Menjaga Siri Tiongkok dan penanya panggilan Mandarin (guzzoni) tetap terhubung langsung ke IP asli, sekaligus mengarahkan Apple Intelligence cloud computing privasi, akses lokasi, dan visual intelligence ke \(policy) di urutan teratas (pastikan node AS yang dipilih telah mengaktifkan udp: true)."

        dns:
          fake-ip-filter:
            - "guzzoni.apple.com"
            - "+.guzzoni.apple.com"
            - "+.siri.apple.com"
            - "dejavu.apple.com"
            - "sequoia.apple.com"
            - "+.smoot.apple.com"
            - "+.push.apple.com"

        rules:
          # 1. Gateway utama suara Siri Tiongkok dan penanya panggilan Mandarin harus langsung ke IP asli (dilarang keras melalui proxy)
          - DOMAIN-SUFFIX,guzzoni.apple.com,DIRECT
          - DOMAIN-SUFFIX,siri.apple.com,DIRECT
          - DOMAIN,dejavu.apple.com,DIRECT
          - DOMAIN,sequoia.apple.com,DIRECT
          - DOMAIN-SUFFIX,smoot.apple.com,DIRECT

          # 2. Verifikasi lokasi regional Apple Intelligence dan relay PCC cloud computing privasi (ditaruh di atas untuk mencegah GEOSITE,apple,DIRECT mendahului)
          - DOMAIN,gspe1-ssl.ls.apple.com,\(policy)
          - DOMAIN-SUFFIX,apple-relay.apple.com,\(policy)
          - DOMAIN-SUFFIX,apple-relay.cloudflare.com,\(policy)
          - DOMAIN-SUFFIX,apple-relay.fastly-edge.com,\(policy)
          - DOMAIN-SUFFIX,apple-relay.akamaized.net,\(policy)
          - DOMAIN-SUFFIX,cp4.cloudflare.com,\(policy)

          # 3. Ekstensi ChatGPT Siri dan visual intelligence (pertanyaan + pencarian gambar Google)
          - DOMAIN-SUFFIX,openai.com,\(policy)
          - DOMAIN-SUFFIX,chatgpt.com,\(policy)
          - DOMAIN-SUFFIX,oaistatic.com,\(policy)
          - DOMAIN-SUFFIX,oaiusercontent.com,\(policy)
          - DOMAIN-SUFFIX,google.com,\(policy)
          - DOMAIN-SUFFIX,googleapis.com,\(policy)
          - DOMAIN-SUFFIX,gstatic.com,\(policy)
        """
    }

    private func exportRuleFileViaShareSheet() {
        let fileName = (ruleFormat == .stashOverride)
            ? "Erosion-AppleIntelligence-CN.stoverride"
            : "Erosion-AppleIntelligence-CN.sgmodule"
        let outURL = fm.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try? fm.removeItem(at: outURL)
            try currentRuleContent().write(to: outURL, atomically: true, encoding: .utf8)
            Haptic.shared.play(.soft)
            presentShareSheet(with: outURL)
        } catch {
            Alertinator.shared.alert(title: "Gagal mengekspor file split-routing!", body: error.localizedDescription)
        }
    }

    private func injectModuleIntoSurge(_ surge: DetectedAppGroupItem) {
        let content = buildSGModuleContent()
        guard let data = content.data(using: .utf8), !data.isEmpty else { return }

        let rootGrant = wq.grantAccess(path: surge.containerURL.path, requireWrite: true)
        guard rootGrant.0 else {
            Alertinator.shared.alert(title: "Gagal mendapatkan izin tulis grup bersama Surge!", body: rootGrant.2)
            return
        }

        // Probe standard Surge AppGroup module directories cleanly
        let candidateSubpaths = [
            "Documents/Profiles/Modules",
            "Profiles/Modules",
            "Modules",
            "Documents"
        ]
        var targetDir = surge.containerURL.appendingPathComponent("Documents")
        for sub in candidateSubpaths {
            let candidate = surge.containerURL.appendingPathComponent(sub)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                targetDir = candidate
                break
            }
        }

        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            _ = wq.grantAccess(path: targetDir.path, requireWrite: true)
            let targetFile = targetDir.appendingPathComponent("Erosion-AppleIntelligence-CN.sgmodule")
            if fm.fileExists(atPath: targetFile.path) {
                let res = writeFileAtomically(data, to: targetFile)
                if !res.0 {
                    throw res.1
                }
            } else {
                try data.write(to: targetFile, options: .atomic)
            }
            Haptic.shared.play(.soft)
            Alertinator.shared.alert(
                title: "Modul split-routing Surge berhasil diinjeksi!",
                body: "File modul telah ditulis:\n\(targetFile.lastPathComponent)\nSilakan buka Surge dan centang aktifkan di daftar \"Modul\"."
            )
        } catch {
            Alertinator.shared.alert(title: "Gagal menulis modul Surge!", body: error.localizedDescription)
        }
    }

    private func scanAppGroups() {
        isScanning = true
        scanSummary = "Sedang menemukan bookmark Safari dan grup aplikasi bersama..."
        DispatchQueue.global(qos: .utility).async {
            // 1. Fast-path: check com.apple.mobilesafari data container first (<20ms via CSStore2)
            var foundSafariDB: String?
            let safariContainer = fsHandlers.getContainerPath(at: FSURL.appContainers, forMatch: "com.apple.mobilesafari")
            if !safariContainer.isEmpty {
                _ = wq.grantAccess(path: safariContainer, requireWrite: false)
                let dbCandidate = (safariContainer as NSString).appendingPathComponent("Library/Safari/Bookmarks.db")
                _ = wq.grantAccess(path: (dbCandidate as NSString).deletingLastPathComponent, requireWrite: false)
                if fm.isReadableFile(atPath: dbCandidate) {
                    foundSafariDB = dbCandidate
                }
            }

            if let earlyDB = foundSafariDB {
                let earlyBookmarks = Self.readSafariBookmarks(at: earlyDB)
                DispatchQueue.main.async {
                    self.safariBookmarksDBPath = earlyDB
                    self.bookmarks = earlyBookmarks
                    self.scanSummary = "Memuat \(earlyBookmarks.count) bookmark Safari · sedang menghitung grup bersama..."
                }
            }

            // 2. Enumerate Shared/AppGroup containers with real-time progress
            let groupPaths = fsHandlers.getDirPaths(FSURL.appGroup.path)
            var foundProxies: [DetectedAppGroupItem] = []

            for (idx, path) in groupPaths.enumerated() {
                if idx % 25 == 0 {
                    DispatchQueue.main.async {
                        self.scanSummary = "Sedang mengidentifikasi grup aplikasi bersama (\(idx) / \(groupPaths.count))..."
                    }
                }
                let url = URL(fileURLWithPath: path)
                guard let gid = getBIDFromXattr(url), !gid.isEmpty else { continue }

                if let client = Self.knownProxyGroupMap[gid] {
                    foundProxies.append(DetectedAppGroupItem(
                        id: url.lastPathComponent,
                        groupID: gid,
                        clientName: client,
                        containerURL: url
                    ))
                } else if foundSafariDB == nil && (gid.lowercased() == "group.com.apple.safari" || gid.lowercased() == "group.com.apple.mobilesafari") {
                    _ = wq.grantAccess(path: url.path, requireWrite: false)
                    let dbCandidate = url.appendingPathComponent("Library/Safari/Bookmarks.db")
                    _ = wq.grantAccess(path: dbCandidate.deletingLastPathComponent().path, requireWrite: false)
                    if fm.isReadableFile(atPath: dbCandidate.path) {
                        foundSafariDB = dbCandidate.path
                    }
                }
            }

            foundProxies.sort { $0.clientName < $1.clientName }

            var extractedBookmarks: [SafariBookmarkRecord] = []
            if let dbPath = foundSafariDB {
                extractedBookmarks = Self.readSafariBookmarks(at: dbPath)
            }

            DispatchQueue.main.async {
                self.proxyGroups = foundProxies
                if !self.hasAutoSelectedFormat {
                    self.hasAutoSelectedFormat = true
                    let hasSurge = foundProxies.contains { $0.groupID.hasPrefix("group.com.nssurge.inc.surge-ios") }
                    let hasStash = foundProxies.contains { $0.groupID == "group.ws.stash.app" }
                    if hasStash && !hasSurge {
                        self.ruleFormat = .stashOverride
                    }
                }
                self.safariBookmarksDBPath = foundSafariDB
                self.bookmarks = extractedBookmarks
                self.scanSummary = "Total \(groupPaths.count) container grup bersama dipindai · terdeteksi \(foundProxies.count) alat proxy dan \(extractedBookmarks.count) bookmark Safari"
                self.isScanning = false
            }
        }
    }

    private static func readSafariBookmarks(at dbPath: String) -> [SafariBookmarkRecord] {
        do {
            return try SQLiteSnapshotHelper.withClonedDatabase(at: dbPath) { db in
                let cols = SQLiteSnapshotHelper.columnNames(in: "bookmarks", db: db)
                guard cols.contains("url") else { return [] }
                let titleCol = cols.contains("title") ? "title" : "''"
                let sql = "SELECT rowid, \(titleCol), url FROM bookmarks WHERE url IS NOT NULL AND url != '' ORDER BY rowid ASC LIMIT 5000;"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
                      let validStmt = stmt else {
                    return []
                }
                defer { sqlite3_finalize(validStmt) }

                var rows: [SafariBookmarkRecord] = []
                while sqlite3_step(validStmt) == SQLITE_ROW {
                    let rowID = SQLiteSnapshotHelper.intCol(validStmt, 0) ?? rows.count
                    let title = SQLiteSnapshotHelper.stringCol(validStmt, 1) ?? ""
                    let url = SQLiteSnapshotHelper.stringCol(validStmt, 2) ?? ""
                    if !url.isEmpty {
                        rows.append(SafariBookmarkRecord(id: rowID, title: title, url: url))
                    }
                }
                return rows
            }
        } catch {
            print("(appgroup) Pembacaan snapshot Bookmark Safari gagal: \(error.localizedDescription)")
            return []
        }
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func exportBookmarksHTML() {
        var lines: [String] = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Safari Bookmarks (Erosion Export)</TITLE>",
            "<H1>Safari Bookmarks</H1>",
            "<DL><p>"
        ]
        for bm in bookmarks {
            let safeURL = Self.escapeHTML(bm.url)
            let safeTitle = Self.escapeHTML(bm.title.isEmpty ? bm.url : bm.title)
            lines.append("    <DT><A HREF=\"\(safeURL)\">\(safeTitle)</A>")
        }
        lines.append("</DL><p>")

        let outURL = fm.temporaryDirectory.appendingPathComponent("SafariBookmarks_Erosion.html")
        do {
            try? fm.removeItem(at: outURL)
            try lines.joined(separator: "\n").write(to: outURL, atomically: true, encoding: .utf8)
            Haptic.shared.play(.soft)
            presentShareSheet(with: outURL)
        } catch {
            Alertinator.shared.alert(title: "Gagal mengekspor bookmark HTML!", body: error.localizedDescription)
        }
    }

    private func exportBookmarksJSON() {
        let outURL = fm.temporaryDirectory.appendingPathComponent("SafariBookmarks_Erosion.json")
        do {
            try? fm.removeItem(at: outURL)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(bookmarks)
            try data.write(to: outURL, options: .atomic)
            Haptic.shared.play(.soft)
            presentShareSheet(with: outURL)
        } catch {
            Alertinator.shared.alert(title: "Gagal mengekspor bookmark JSON!", body: error.localizedDescription)
        }
    }
}
