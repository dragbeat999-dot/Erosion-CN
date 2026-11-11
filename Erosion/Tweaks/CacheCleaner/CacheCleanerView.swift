//
//  CacheCleanerView.swift
//  Erosion
//
//  Safe container-level cache & temporary file cleaner for reclaiming bloated iOS "System Data" storage.
//

import SwiftUI

struct ContainerCacheEntry: Identifiable {
    let id: String
    let bundleID: String
    let displayTitle: String
    let containerURL: URL
    var cachesBytes: Int64
    var tmpBytes: Int64
    var isSelected: Bool

    var totalCleanableBytes: Int64 {
        cachesBytes + tmpBytes
    }
}

struct CacheCleanerView: View {
    @State private var isScanning = false
    @State private var isCleaning = false
    @State private var entries: [ContainerCacheEntry] = []
    @State private var searchText = ""
    @State private var includeSystemContainers = false
    @AppStorage("totalFreedBytesHistory") private var totalFreedBytesHistory: Int = 0

    private static let protectedBundleIDs: Set<String> = [
        "com.jbdotparty.Erosion",
        "com.apple.PosterBoard",
        "com.apple.springboard",
        "com.apple.Preferences",
        "com.apple.mobilephone"
    ]

    private var filteredEntries: [ContainerCacheEntry] {
        let base = includeSystemContainers
            ? entries
            : entries.filter { !$0.bundleID.hasPrefix("com.apple.") || $0.bundleID == "com.apple.mobilesafari" }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(trimmed) ||
            $0.bundleID.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var totalReclaimableBytes: Int64 {
        filteredEntries.reduce(0) { $0 + $1.totalCleanableBytes }
    }

    private var selectedReclaimableBytes: Int64 {
        filteredEntries.filter(\.isSelected).reduce(0) { $0 + $1.totalCleanableBytes }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cache yang aman dibebaskan saat ini")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(AppContainerDirectoryHelper.formatBytes(totalReclaimableBytes))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(totalReclaimableBytes > 0 ? Color.accentColor : Color.secondary)
                        }
                        Spacer()
                        if totalFreedBytesHistory > 0 {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Total yang telah dibebaskan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(AppContainerDirectoryHelper.formatBytes(Int64(totalFreedBytesHistory)))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    Divider()

                    HStack {
                        Button {
                            scanCaches()
                        } label: {
                            Label("Pindai Ulang", systemImage: "arrow.clockwise")
                                .font(.subheadline)
                        }
                        .disabled(isScanning || isCleaning)

                        Spacer()

                        Button(role: .destructive) {
                            let selectedCount = filteredEntries.filter(\.isSelected).count
                            guard selectedCount > 0 else { return }
                            Alertinator.shared.alert(
                                title: "Konfirmasi membersihkan cache aplikasi terpilih?",
                                body: "Akan membersihkan Library/Caches dan fragmen sementara tmp di dalam container \(selectedCount) aplikasi (perkiraan pembebasan \(AppContainerDirectoryHelper.formatBytes(selectedReclaimableBytes))).\n\nJaminan keamanan: Tidak akan menyentuh Documents, basis data riwayat obrolan, atau konfigurasi login.",
                                actionLabel: "Bersihkan Sekarang",
                                action: {
                                    cleanSelectedEntries()
                                }
                            )
                        } label: {
                            Label("Bersihkan Terpilih Sekali Klik (\(AppContainerDirectoryHelper.formatBytes(selectedReclaimableBytes)))", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                        .disabled(isScanning || isCleaning || selectedReclaimableBytes <= 0)
                    }
                }
                .padding(.vertical, 4)

                PlainToggle(
                    "Tampilkan Container Komponen Sistem (com.apple.*)",
                    subtitle: "Secara default mencakup cache aplikasi pihak ketiga dan Safari",
                    isOn: $includeSystemContainers
                )
            } header: {
                HeaderLabel("Ringkasan Pembebasan Ruang", symbol: "chart.pie.fill")
            } footer: {
                Text("Alat ini hanya membersihkan Library/Caches, tmp, dan cache web WebKit di setiap container, mempertahankan direktori itu sendiri beserta izinnya, 100% tidak memengaruhi riwayat obrolan aplikasi, status login akun, dan dokumen pengguna.")
            }

            Section {
                if isScanning || isCleaning {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(isCleaning ? "Sedang membersihkan cache container terpilih dengan aman..." : "Sedang memindai ukuran cache container aplikasi...")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                } else if filteredEntries.isEmpty {
                    Text("Tidak ditemukan cache aplikasi yang dapat dibersihkan")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredEntries) { entry in
                        HStack(spacing: 12) {
                            Button {
                                toggleSelection(for: entry.id)
                            } label: {
                                Image(systemName: entry.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(entry.isSelected ? Color.accentColor : Color.secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.displayTitle)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("Caches: \(AppContainerDirectoryHelper.formatBytes(entry.cachesBytes)) · tmp: \(AppContainerDirectoryHelper.formatBytes(entry.tmpBytes))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(AppContainerDirectoryHelper.formatBytes(entry.totalCleanableBytes))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(entry.totalCleanableBytes > 50 * 1024 * 1024 ? Color.orange : Color.primary)

                                HStack(spacing: 10) {
                                    NavigationLink {
                                        ContainerSubdirBrowserView(containerURL: entry.containerURL, relativeSubpath: "Library/Caches")
                                    } label: {
                                        Text("Lihat")
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.borderless)

                                    Button(role: .destructive) {
                                        cleanSingleEntry(entry)
                                    } label: {
                                        Text("Bersihkan")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                HStack {
                    HeaderLabel("Peringkat Ukuran Cache Container (\(filteredEntries.count))", symbol: "trash.slash.fill")
                    Spacer()
                    if !filteredEntries.isEmpty {
                        Button(filteredEntries.allSatisfy(\.isSelected) ? "Batal Pilih Semua" : "Pilih Semua") {
                            let target = !filteredEntries.allSatisfy(\.isSelected)
                            let visibleIDs = Set(filteredEntries.map(\.id))
                            for idx in entries.indices where visibleIDs.contains(entries[idx].id) {
                                entries[idx].isSelected = target
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Pembersihan Cache Container")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Cari nama aplikasi atau Bundle ID")
        .onChange(of: includeSystemContainers) {
            if includeSystemContainers && !entries.contains(where: { $0.bundleID.hasPrefix("com.apple.") && $0.bundleID != "com.apple.mobilesafari" }) && !isScanning {
                scanCaches()
            }
        }
        .onAppear {
            if entries.isEmpty && !isScanning {
                scanCaches()
            }
        }
    }

    private func toggleSelection(for id: String) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].isSelected.toggle()
        }
    }

    private func scanCaches() {
        let wantSystem = includeSystemContainers
        isScanning = true
        DispatchQueue.global(qos: .utility).async {
            let rawPaths = fsHandlers.getDirPaths(FSURL.appContainers.path)
            var result: [ContainerCacheEntry] = []
            let selfBID = Bundle.main.bundleIdentifier ?? "com.jbdotparty.Erosion"

            for rawPath in rawPaths {
                let url = URL(fileURLWithPath: rawPath)

                // Fast pre-filter via CSStore2 without touching containermanagerd IPC!
                if let knownBID = CSStoreEngine.shared.bundleID(forContainerPath: url.path, allowDiscovery: false) {
                    if knownBID == selfBID || Self.protectedBundleIDs.contains(knownBID) {
                        continue
                    }
                    if !wantSystem && knownBID.hasPrefix("com.apple.") && knownBID != "com.apple.mobilesafari" {
                        continue
                    }
                }

                guard let bid = getBIDFromXattr(url),
                      !bid.isEmpty,
                      bid != selfBID,
                      !Self.protectedBundleIDs.contains(bid) else { continue }

                if !wantSystem && bid.hasPrefix("com.apple.") && bid != "com.apple.mobilesafari" {
                    continue
                }

                let wasActive = wq.hasActiveAccess(path: url.path)
                guard wq.grantAccess(path: url.path, requireWrite: false).0 else { continue }
                defer {
                    if !wasActive {
                        wq.releaseAccess(path: url.path)
                    }
                }

                let cachesURL = url.appendingPathComponent("Library/Caches")
                let tmpURL = url.appendingPathComponent("tmp")

                let cBytes = AppContainerDirectoryHelper.directorySize(at: cachesURL, maxDepth: 5)
                let tBytes = AppContainerDirectoryHelper.directorySize(at: tmpURL, maxDepth: 4)

                let total = cBytes + tBytes
                guard total > 4096 else { continue }

                result.append(ContainerCacheEntry(
                    id: url.lastPathComponent,
                    bundleID: bid,
                    displayTitle: AppContainerDirectoryHelper.displayName(for: bid),
                    containerURL: url,
                    cachesBytes: cBytes,
                    tmpBytes: tBytes,
                    isSelected: !bid.hasPrefix("com.apple.") && total >= 1024 * 1024
                ))
            }

            result.sort { $0.totalCleanableBytes > $1.totalCleanableBytes }

            DispatchQueue.main.async {
                self.entries = result
                self.isScanning = false
            }
        }
    }

    private func cleanSingleEntry(_ entry: ContainerCacheEntry) {
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let freed = Self.purgeCacheContents(for: entry)
            DispatchQueue.main.async {
                if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                    entries.remove(at: idx)
                }
                totalFreedBytesHistory += Int(max(freed, 0))
                isCleaning = false
                Haptic.shared.play(.soft)
                Alertinator.shared.alert(
                    title: "Pembersihan selesai!",
                    body: "Telah dengan aman membersihkan cache «\(entry.displayTitle)», membebaskan ruang \(AppContainerDirectoryHelper.formatBytes(freed))."
                )
            }
        }
    }

    private func cleanSelectedEntries() {
        let targets = filteredEntries.filter(\.isSelected)
        guard !targets.isEmpty else { return }
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalFreed: Int64 = 0
            var cleanedIDs: Set<String> = []
            for target in targets {
                let freed = Self.purgeCacheContents(for: target)
                totalFreed += freed
                cleanedIDs.insert(target.id)
            }
            DispatchQueue.main.async {
                entries.removeAll { cleanedIDs.contains($0.id) }
                totalFreedBytesHistory += Int(max(totalFreed, 0))
                isCleaning = false
                Haptic.shared.play(.soft)
                Alertinator.shared.alert(
                    title: "Pembersihan massal selesai!",
                    body: "Berhasil membersihkan cache redundan dan file sementara dari \(cleanedIDs.count) aplikasi, total membebaskan \(AppContainerDirectoryHelper.formatBytes(totalFreed)) ruang penyimpanan!"
                )
            }
        }
    }

    private static func purgeCacheContents(for entry: ContainerCacheEntry) -> Int64 {
        let wasActive = wq.hasActiveAccess(path: entry.containerURL.path)
        guard wq.grantAccess(path: entry.containerURL.path).0 else { return 0 }
        defer {
            if !wasActive {
                wq.releaseAccess(path: entry.containerURL.path)
            }
        }

        let dirs = [
            entry.containerURL.appendingPathComponent("Library/Caches"),
            entry.containerURL.appendingPathComponent("tmp"),
            entry.containerURL.appendingPathComponent("Library/WebKit/WebsiteData/CacheStorage")
        ]
        var totalFreed: Int64 = 0
        for dir in dirs {
            var dirSt = stat()
            guard lstat(dir.path, &dirSt) == 0, (dirSt.st_mode & S_IFMT) == S_IFDIR else { continue }
            let subWasActive = wq.hasActiveAccess(path: dir.path)
            _ = wq.grantAccess(path: dir.path)
            defer {
                if !subWasActive {
                    wq.releaseAccess(path: dir.path)
                }
            }
            let before = AppContainerDirectoryHelper.directorySize(at: dir, maxDepth: 5)
            guard let children = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for child in children {
                guard !child.contains("/"), child != ".", child != ".." else { continue }
                if entry.bundleID == "com.apple.mobilephone" && child == "TelephonyUI-10" {
                    continue
                }
                let childURL = dir.appendingPathComponent(child)
                var childSt = stat()
                guard lstat(childURL.path, &childSt) == 0 else { continue }
                let mode = childSt.st_mode & S_IFMT
                // Only remove regular files and regular subdirectories; skip sockets/FIFOs/symlinks
                if mode == S_IFREG || mode == S_IFDIR {
                    try? fm.removeItem(at: childURL)
                }
            }
            let after = AppContainerDirectoryHelper.directorySize(at: dir, maxDepth: 5)
            totalFreed += max(0, before - after)
        }
        return totalFreed
    }
}
