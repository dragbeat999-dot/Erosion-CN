//
//  AppDataBackupView.swift
//  Erosion
//
//  Third-party App & Game save backup, restore, and direct Plist/JSON editor launcher.
//

import SwiftUI
import ZIPFoundation
import UniformTypeIdentifiers

enum AppContainerDirectoryHelper {
    static let knownAppNames: [String: String] = [
        "com.tencent.xin": "WeChat",
        "com.tencent.mqq": "QQ",
        "com.ss.iphone.ugc.Aweme": "TikTok",
        "tv.danmaku.bilianime": "Bilibili",
        "com.xingin.discover": "Xiaohongshu",
        "com.taobao.taobao4iphone": "Taobao",
        "com.alipay.iphoneclient": "Alipay",
        "com.jingdong.app.mall": "JD.com",
        "com.meituan.imeituan": "Meituan",
        "com.netease.cloudmusic": "NetEase Cloud Music",
        "com.tencent.QQMusic": "QQ Music",
        "com.zhihu.ios": "Zhihu",
        "com.sina.weibo": "Weibo",
        "com.baidu.BaiduMobile": "Baidu",
        "com.autonavi.amap": "Amap",
        "com.tencent.smoba": "Honor of Kings",
        "com.tencent.tmgp.pubgmhd": "PUBG Mobile (China)",
        "com.tencent.jkchess": "Teamfight Tactics (China)",
        "com.miHoYo.Yuanshen": "Genshin Impact",
        "com.miHoYo.GenshinImpact": "Genshin Impact (Global)",
        "com.miHoYo.hkrpg": "Honkai: Star Rail",
        "com.miHoYo.Nap": "Zenless Zone Zero",
        "com.hypergryph.arknights": "Arknights",
        "com.chucklefish.stardewvalley": "Stardew Valley",
        "com.and.games505.TerrariaPaid": "Terraria",
        "com.mojang.minecraftpe": "Minecraft",
        "com.popcap.ios.PvZ2": "Plants vs. Zombies 2",
        "com.SoulGame.SoulKnight": "Soul Knight",
        "com.locojoy.balatro": "Balatro",
        "com.NSSurge.inc.surge-ios": "Surge",
        "com.luo.quantumult-x": "Quantumult X",
        "com.liguangming.Shadowrocket": "Shadowrocket",
        "org.telegram.Telegram-iOS": "Telegram",
        "com.burbn.instagram": "Instagram",
        "com.atebits.Tweetie2": "X (Twitter)",
        "com.google.ios.youtube": "YouTube",
        "com.openai.chat": "ChatGPT",
        "com.apple.mobilesafari": "Safari",
        "com.apple.Music": "Apple Music",
        "com.apple.DocumentsApp": "File"
    ]

    static func displayName(for bundleID: String) -> String {
        if let known = knownAppNames[bundleID] {
            return "\(known) (\(bundleID))"
        }
        if let csName = CSStoreEngine.shared.localizedName(forBundleID: bundleID),
           !csName.isEmpty, csName != bundleID {
            return "\(csName) (\(bundleID))"
        }
        return bundleID
    }

    static func directorySize(at url: URL, maxDepth: Int = 6, currentDepth: Int = 0) -> Int64 {
        guard currentDepth <= maxDepth else { return 0 }
        guard let names = try? fm.contentsOfDirectory(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        for name in names {
            let childPath = (url.path as NSString).appendingPathComponent(name)
            var st = stat()
            if lstat(childPath, &st) == 0 {
                let mode = st.st_mode & S_IFMT
                if mode == S_IFREG {
                    total += Int64(st.st_size)
                } else if mode == S_IFDIR {
                    total += directorySize(at: URL(fileURLWithPath: childPath), maxDepth: maxDepth, currentDepth: currentDepth + 1)
                }
            }
        }
        return total
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(bytes, 0))
    }
}

struct AppSaveContainerItem: Identifiable {
    let id: String
    let bundleID: String
    let displayTitle: String
    let containerURL: URL
    let saveDataSize: Int64
}

struct LocalSaveBackupItem: Identifiable {
    let id: String
    let fileURL: URL
    let bundleID: String
    let createdAt: Date
    let fileSize: Int64
}

struct AppDataBackupView: View {
    @State private var isScanning = false
    @State private var scanProgressText = "Sedang memindai container data aplikasi di perangkat..."
    @State private var containers: [AppSaveContainerItem] = []
    @State private var backups: [LocalSaveBackupItem] = []
    @State private var searchText = ""
    @State private var includeSystemApps = false
    @State private var showBackupImporter = false

    private static let backupsRootURL = URL.documentsDirectory.appendingPathComponent("AppDataBackups")

    private var filteredContainers: [AppSaveContainerItem] {
        let base = includeSystemApps
            ? containers
            : containers.filter { !$0.bundleID.hasPrefix("com.apple.") }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
            $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Button {
                        showBackupImporter = true
                    } label: {
                        Label("Impor Paket Cadangan Eksternal (.zip)", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                    Button {
                        scanAllContainers()
                    } label: {
                        Label("Segarkan Daftar", systemImage: "arrow.clockwise")
                    }
                    .disabled(isScanning)
                }
                PlainToggle(
                    "Tampilkan Container Aplikasi Sistem Bawaan (com.apple.*)",
                    subtitle: "Secara default hanya menampilkan container aplikasi dan game pihak ketiga",
                    isOn: $includeSystemApps
                )
            } header: {
                HeaderLabel("Kontrol Pencadangan dan Penyaringan", symbol: "slider.horizontal.3")
            }

            if !backups.isEmpty {
                Section {
                    ForEach(backups) { backup in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(AppContainerDirectoryHelper.displayName(for: backup.bundleID))
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(AppContainerDirectoryHelper.formatBytes(backup.fileSize))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(backup.fileURL.lastPathComponent)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            HStack(spacing: 14) {
                                Button {
                                    Alertinator.shared.alert(
                                        title: "Yakin ingin memulihkan cadangan penyimpanan ini?",
                                        body: "Akan memulihkan penyimpanan Documents dan Preferences dari \(backup.fileURL.lastPathComponent) ke container «\(backup.bundleID)» saat ini (otomatis mencocokkan UUID container terbaru setelah instalasi ulang). Harap tutup aplikasi target di latar belakang sebelum memulihkan!",
                                        actionLabel: "Konfirmasi Pemulihan",
                                        action: {
                                            restoreBackup(backup)
                                        }
                                    )
                                } label: {
                                    Label("Pulihkan Sekali Klik", systemImage: "arrow.uturn.backward.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    presentShareSheet(with: backup.fileURL)
                                } label: {
                                    Label("Ekspor & Bagikan", systemImage: "square.and.arrow.up")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                Spacer()

                                Button(role: .destructive) {
                                    deleteBackup(backup)
                                } label: {
                                    Label("Hapus", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 3)
                    }
                } header: {
                    HeaderLabel("Cadangan Penyimpanan Tersimpan Lokal (\(backups.count))", symbol: "archivebox.fill")
                } footer: {
                    Text("Meskipun meng-uninstal dan menginstal ulang game atau aplikasi menyebabkan UUID container berubah, menekan \"Pulihkan Sekali Klik\" akan otomatis menemukan container terbaru berdasarkan Bundle ID dan menulis kembali penyimpanan secara in-place.")
                }
            }

            Section {
                if isScanning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(scanProgressText)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if filteredContainers.isEmpty {
                    Text("Tidak ditemukan container data aplikasi yang cocok")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredContainers) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.displayTitle)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Spacer()
                                Text(AppContainerDirectoryHelper.formatBytes(item.saveDataSize))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("UUID Container: \(item.containerURL.lastPathComponent)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 12) {
                                Button {
                                    backupContainer(item)
                                } label: {
                                    Label("Cadangkan Penyimpanan", systemImage: "externaldrive.badge.plus")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                NavigationLink {
                                    ContainerSubdirBrowserView(containerURL: item.containerURL, relativeSubpath: "Documents")
                                } label: {
                                    Label("Ubah Documents", systemImage: "folder.badge.gearshape")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                NavigationLink {
                                    ContainerSubdirBrowserView(containerURL: item.containerURL, relativeSubpath: "Library/Preferences")
                                } label: {
                                    Label("Ubah Plist Konfigurasi", systemImage: "doc.text.magnifyingglass")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)

                                NavigationLink {
                                    ContainerSubdirBrowserView(containerURL: item.containerURL, relativeSubpath: nil)
                                } label: {
                                    Label("Direktori Lengkap", systemImage: "folder")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                HeaderLabel("Daftar Penyimpanan Aplikasi dan Game (\(filteredContainers.count))", symbol: "gamecontroller.fill")
            } footer: {
                Text("Menekan \"Cadangkan Penyimpanan\" akan mengemas Documents dan Library/Preferences aplikasi tersebut menjadi ZIP; menekan \"Ubah Documents\" atau \"Ubah Plist Konfigurasi\" akan langsung membuka editor Plist/teks lossless bawaan untuk mengubah nilai atau konfigurasi game.")
            }
        }
        .navigationTitle("Manajemen Penyimpanan Aplikasi dan Game")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Cari nama aplikasi atau Bundle ID")
        .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.zip, .item]) { result in
            handleImportBackup(result)
        }
        .onChange(of: includeSystemApps) {
            if includeSystemApps && !containers.contains(where: { $0.bundleID.hasPrefix("com.apple.") }) && !isScanning {
                scanAllContainers()
            }
        }
        .onAppear {
            loadLocalBackups()
            if containers.isEmpty && !isScanning {
                scanAllContainers()
            }
        }
    }

    private func ensureBackupDir() {
        try? fm.createDirectory(at: Self.backupsRootURL, withIntermediateDirectories: true)
        mgExcludeFromCloudBackup(Self.backupsRootURL)
    }

    private func loadLocalBackups() {
        ensureBackupDir()
        guard let urls = try? fm.contentsOfDirectory(
            at: Self.backupsRootURL,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey]
        ) else {
            return
        }
        var items: [LocalSaveBackupItem] = []
        for url in urls where url.pathExtension.lowercased() == "zip" {
            let baseName = url.deletingPathExtension().lastPathComponent
            let bundleID: String
            if let range = baseName.range(of: "__", options: .backwards) {
                bundleID = String(baseName[..<range.lowerBound])
            } else {
                bundleID = baseName
            }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date()
            items.append(LocalSaveBackupItem(
                id: url.lastPathComponent,
                fileURL: url,
                bundleID: bundleID,
                createdAt: date,
                fileSize: size
            ))
        }
        items.sort { $0.createdAt > $1.createdAt }
        backups = items
    }

    private static let protectedSystemBundleIDs: Set<String> = [
        "com.jbdotparty.Erosion",
        "com.apple.springboard",
        "com.apple.PosterBoard",
        "com.apple.Preferences"
    ]

    private func scanAllContainers() {
        let wantSystem = includeSystemApps
        isScanning = true
        scanProgressText = "Sedang memindai container data aplikasi di perangkat..."
        DispatchQueue.global(qos: .utility).async {
            let rawPaths = fsHandlers.getDirPaths(FSURL.appContainers.path)
            var discovered: [AppSaveContainerItem] = []
            for rawPath in rawPaths {
                let url = URL(fileURLWithPath: rawPath)

                if let fastBID = CSStoreEngine.shared.bundleID(forContainerPath: url.path, allowDiscovery: false) {
                    if Self.protectedSystemBundleIDs.contains(fastBID) { continue }
                    if !wantSystem && fastBID.hasPrefix("com.apple.") { continue }
                }

                guard let bid = getBIDFromXattr(url),
                      !bid.isEmpty,
                      !Self.protectedSystemBundleIDs.contains(bid) else { continue }
                if !wantSystem && bid.hasPrefix("com.apple.") { continue }

                let wasActive = wq.hasActiveAccess(path: url.path)
                guard wq.grantAccess(path: url.path, requireWrite: false).0 else { continue }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: url.path)
                    }
                }

                let docsURL = url.appendingPathComponent("Documents")
                let prefsURL = url.appendingPathComponent("Library/Preferences")
                let docsSize = AppContainerDirectoryHelper.directorySize(at: docsURL, maxDepth: 4)
                let prefsSize = AppContainerDirectoryHelper.directorySize(at: prefsURL, maxDepth: 2)

                discovered.append(AppSaveContainerItem(
                    id: url.lastPathComponent,
                    bundleID: bid,
                    displayTitle: AppContainerDirectoryHelper.displayName(for: bid),
                    containerURL: url,
                    saveDataSize: docsSize + prefsSize
                ))
            }

            discovered.sort {
                if $0.saveDataSize != $1.saveDataSize {
                    return $0.saveDataSize > $1.saveDataSize
                }
                return $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.containers = discovered
                self.isScanning = false
            }
        }
    }

    private func backupContainer(_ item: AppSaveContainerItem) {
        ensureBackupDir()
        DispatchQueue.global(qos: .userInitiated).async {
            let stagingDir = fm.temporaryDirectory.appendingPathComponent("SaveBackup_\(UUID().uuidString)")
            defer { try? fm.removeItem(at: stagingDir) }

            do {
                try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                let wasActive = wq.hasActiveAccess(path: item.containerURL.path)
                guard wq.grantAccess(path: item.containerURL.path, requireWrite: false).0 else {
                    throw "Tidak dapat memperoleh izin baca container aplikasi ini"
                }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: item.containerURL.path)
                    }
                }

                let docsSrc = item.containerURL.appendingPathComponent("Documents")
                let prefsSrc = item.containerURL.appendingPathComponent("Library/Preferences")
                var copiedAny = false

                if fm.fileExists(atPath: docsSrc.path) {
                    _ = wq.grantAccess(path: docsSrc.path, requireWrite: false)
                    try fm.copyItem(at: docsSrc, to: stagingDir.appendingPathComponent("Documents"))
                    copiedAny = true
                }
                if fm.fileExists(atPath: prefsSrc.path) {
                    _ = wq.grantAccess(path: prefsSrc.path, requireWrite: false)
                    let libDest = stagingDir.appendingPathComponent("Library")
                    try fm.createDirectory(at: libDest, withIntermediateDirectories: true)
                    try fm.copyItem(at: prefsSrc, to: libDest.appendingPathComponent("Preferences"))
                    copiedAny = true
                }

                guard copiedAny else {
                    throw "Tidak ditemukan data direktori Documents atau Preferences yang dapat dicadangkan dalam container aplikasi ini."
                }

                let meta: [String: String] = [
                    "bundleID": item.bundleID,
                    "createdAt": ISO8601DateFormatter().string(from: Date())
                ]
                let metaData = try PropertyListSerialization.data(fromPropertyList: meta, format: .xml, options: 0)
                try metaData.write(to: stagingDir.appendingPathComponent("BackupManifest.plist"), options: .atomic)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let zipName = "\(item.bundleID)__\(formatter.string(from: Date())).zip"
                let zipURL = Self.backupsRootURL.appendingPathComponent(zipName)
                if fm.fileExists(atPath: zipURL.path) {
                    try fm.removeItem(at: zipURL)
                }

                try fm.zipItem(at: stagingDir, to: zipURL, shouldKeepParent: false)
                mgExcludeFromCloudBackup(zipURL)

                DispatchQueue.main.async {
                    loadLocalBackups()
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "Pencadangan penyimpanan berhasil!",
                        body: "File cadangan telah dibuat: \(zipName)\nAnda dapat memulihkan atau mengekspor berbagi kapan saja melalui \"Cadangan Penyimpanan Tersimpan Lokal\" di atas."
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    Alertinator.shared.alert(title: "Gagal mencadangkan penyimpanan!", body: error.localizedDescription)
                }
            }
        }
    }

    private func restoreBackup(_ backup: LocalSaveBackupItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            let extractDir = fm.temporaryDirectory.appendingPathComponent("RestoreSave_\(UUID().uuidString)")
            defer { try? fm.removeItem(at: extractDir) }

            do {
                guard let archive = try? Archive(url: backup.fileURL, accessMode: .read) else {
                    throw "Tidak dapat membaca arsip cadangan, file mungkin rusak!"
                }
                let destStd = extractDir.standardizedFileURL
                let destPrefix = destStd.path.hasSuffix("/") ? destStd.path : destStd.path + "/"
                for entry in archive {
                    let entryPath = entry.path
                    if entryPath.hasPrefix("/") || entryPath.split(separator: "/").contains("..") || entryPath.split(separator: "\\").contains("..") {
                        throw "Terdeteksi arsip cadangan berisi entri path traversal ilegal (\(entryPath)), pemulihan ditolak!"
                    }
                    let resolvedPath = destStd.appendingPathComponent(entryPath).standardizedFileURL.path
                    if resolvedPath != destStd.path && !resolvedPath.hasPrefix(destPrefix) {
                        throw "Terdeteksi entri arsip cadangan melewati batas (\(entryPath)), pemulihan ditolak!"
                    }
                }

                try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)
                try fm.unzipItem(at: backup.fileURL, to: extractDir)

                var resolvedBundleID = backup.bundleID
                let manifestURL = extractDir.appendingPathComponent("BackupManifest.plist")
                if let mData = try? Data(contentsOf: manifestURL),
                   let mDict = try? PropertyListSerialization.propertyList(from: mData, options: [], format: nil) as? [String: Any],
                   let mBID = mDict["bundleID"] as? String, !mBID.isEmpty {
                    resolvedBundleID = mBID
                }

                guard !Self.protectedSystemBundleIDs.contains(resolvedBundleID) else {
                    DispatchQueue.main.async {
                        Alertinator.shared.alert(title: "Pagar pengaman memblokir!", body: "Dilarang memulihkan arsip cadangan eksternal ke container sistem inti yang dilindungi.")
                    }
                    return
                }

                var targetContainerPath = ""
                var preGrantedCached = false
                if let matched = containers.first(where: { $0.bundleID == resolvedBundleID }) {
                    let cachedPath = matched.containerURL.path
                    let wasCachedActive = wq.hasActiveAccess(path: cachedPath)
                    if wq.grantAccess(path: cachedPath).0 && fm.fileExists(atPath: cachedPath) && getBIDFromXattr(URL(fileURLWithPath: cachedPath)) == resolvedBundleID {
                        targetContainerPath = cachedPath
                        preGrantedCached = !wasCachedActive
                    } else if !wasCachedActive {
                        wq.releaseAccess(path: cachedPath)
                    }
                }
                if targetContainerPath.isEmpty {
                    targetContainerPath = fsHandlers.getContainerPath(forMatch: resolvedBundleID)
                }

                guard !targetContainerPath.isEmpty else {
                    DispatchQueue.main.async {
                        Alertinator.shared.alert(
                            title: "Container aplikasi target tidak ditemukan!",
                            body: "Saat ini tidak terdeteksi container data «\(resolvedBundleID)» di perangkat ini, silakan instal dan buka aplikasi tersebut setidaknya satu kali terlebih dahulu lalu coba lagi."
                        )
                    }
                    return
                }

                let containerURL = URL(fileURLWithPath: targetContainerPath)
                let wasActive = preGrantedCached ? false : wq.hasActiveAccess(path: containerURL.path)
                guard wq.grantAccess(path: containerURL.path).0 else {
                    throw "Tidak dapat memperoleh izin tulis container target"
                }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: containerURL.path)
                    }
                }

                var restoredFiles = 0
                var restoredPrefs = false
                let docsExtract = extractDir.appendingPathComponent("Documents")
                if fm.fileExists(atPath: docsExtract.path) {
                    let docsTarget = containerURL.appendingPathComponent("Documents")
                    try? fm.createDirectory(at: docsTarget, withIntermediateDirectories: true)
                    _ = wq.grantAccess(path: docsTarget.path)
                    restoredFiles += Self.mergeDirectoryInPlace(from: docsExtract, to: docsTarget)
                }

                let prefsExtract = extractDir.appendingPathComponent("Library/Preferences")
                if fm.fileExists(atPath: prefsExtract.path) {
                    let prefsTarget = containerURL.appendingPathComponent("Library/Preferences")
                    try? fm.createDirectory(at: prefsTarget, withIntermediateDirectories: true)
                    _ = wq.grantAccess(path: prefsTarget.path)
                    let pCount = Self.mergeDirectoryInPlace(from: prefsExtract, to: prefsTarget)
                    if pCount > 0 {
                        restoredPrefs = true
                    }
                    restoredFiles += pCount
                }

                let cfprefsHint = restoredPrefs ? "\n\nPetunjuk: Pemulihan ini mencakup preferensi Preferences, disarankan menutup sepenuhnya aplikasi target di multitasking latar belakang atau memuat ulang perangkat (Respring) agar cfprefsd sistem memuat ulang konfigurasi." : ""
                DispatchQueue.main.async {
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "Pemulihan penyimpanan selesai!",
                        body: "Berhasil memulihkan \(restoredFiles) file penyimpanan/konfigurasi secara in-place ke container «\(resolvedBundleID)»." + cfprefsHint
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    Alertinator.shared.alert(title: "Gagal memulihkan penyimpanan!", body: error.localizedDescription)
                }
            }
        }
    }

    private static func mergeDirectoryInPlace(from srcDir: URL, to dstDir: URL) -> Int {
        try? fm.createDirectory(at: dstDir, withIntermediateDirectories: true)
        guard let names = try? fm.contentsOfDirectory(atPath: srcDir.path) else { return 0 }
        var count = 0
        for name in names {
            guard !name.contains("/"), name != ".", name != ".." else { continue }
            let srcURL = srcDir.appendingPathComponent(name)
            let dstURL = dstDir.appendingPathComponent(name)
            var st = stat()
            guard lstat(srcURL.path, &st) == 0 else { continue }
            let mode = st.st_mode & S_IFMT
            if mode == S_IFDIR {
                count += mergeDirectoryInPlace(from: srcURL, to: dstURL)
            } else if mode == S_IFREG, let data = try? Data(contentsOf: srcURL) {
                var dstSt = stat()
                if lstat(dstURL.path, &dstSt) == 0 {
                    // Never overwrite a symlink in destination
                    guard (dstSt.st_mode & S_IFMT) == S_IFREG else { continue }
                    if writeFileAtomically(data, to: dstURL, allowEmpty: true).0 {
                        count += 1
                    }
                } else {
                    if data.isEmpty {
                        if (try? data.write(to: dstURL, options: .atomic)) != nil {
                            count += 1
                        }
                    } else if writeFileTemp(data, to: dstURL).0 {
                        count += 1
                    }
                }
            }
        }
        return count
    }

    private func deleteBackup(_ backup: LocalSaveBackupItem) {
        try? fm.removeItem(at: backup.fileURL)
        loadLocalBackups()
    }

    private func handleImportBackup(_ result: Result<URL, Error>) {
        ensureBackupDir()
        switch result {
        case .success(let url):
            let stopAccess = url.startAccessingSecurityScopedResource()
            defer {
                if stopAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let destURL = Self.backupsRootURL.appendingPathComponent(url.lastPathComponent)
            try? fm.removeItem(at: destURL)
            do {
                try fm.copyItem(at: url, to: destURL)
                mgExcludeFromCloudBackup(destURL)
                loadLocalBackups()
                Haptic.shared.play(.soft)
            } catch {
                Alertinator.shared.alert(title: "Gagal mengimpor paket cadangan!", body: error.localizedDescription)
            }
        case .failure(let error):
            Alertinator.shared.alert(title: "Gagal mengimpor paket cadangan!", body: error.localizedDescription)
        }
    }
}

struct ContainerSubdirBrowserView: View {
    let containerURL: URL
    let relativeSubpath: String?
    @State private var targetURL: URL?
    @State private var errorMsg: String?

    var body: some View {
        Group {
            if let targetURL {
                FileBrowserView(path: targetURL, shouldGrant: true)
            } else if let errorMsg {
                List {
                    CompactAlert(title: "Tidak dapat membuka direktori container!", symbol: "folder.badge.questionmark", text: errorMsg)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Sedang memberi izin dan membuka direktori container...")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            guard targetURL == nil && errorMsg == nil else { return }
            let rootGrant = wq.grantAccess(path: containerURL.path)
            guard rootGrant.0 else {
                errorMsg = "Tidak dapat memperoleh izin direktori root container aplikasi: \(rootGrant.2)"
                return
            }
            if let relativeSubpath, !relativeSubpath.isEmpty {
                let subURL = containerURL.appendingPathComponent(relativeSubpath)
                try? fm.createDirectory(at: subURL, withIntermediateDirectories: true)
                _ = wq.grantAccess(path: subURL.path)
                targetURL = subURL
            } else {
                targetURL = containerURL
            }
        }
    }
}
