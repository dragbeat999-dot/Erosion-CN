//
//  PosterBoardView.swift
//  Erosion
//
//  Created by lunginspector on 8/19/26.
//

import SwiftUI

import UniformTypeIdentifiers

let pbHandler = PBHandler()

enum PBMsg {
    static var noTendies = "Ketuk di sini atau tombol di bawah untuk mengimpor paket wallpaper .tendies, lalu mulai terapkan wallpaper layar kunci kustom."
    static var tooManyTendies = "Maksimal hanya 15 wallpaper yang dapat diaktifkan sekaligus. Harap hapus centang pada paket wallpaper lain terlebih dahulu sebelum mencoba lagi!"
    static var limitWarning = "Anda memilih lebih dari 5 wallpaper. Beberapa wallpaper mungkin tidak tampil dengan benar. Yakin ingin tetap melanjutkan penerapan?"
    static var corruption = "Pastikan paket wallpaper yang dipilih tidak rusak, lalu coba lagi."
    static var finishApply = "Setelah mengetuk lanjutkan, PosterBoard akan terbuka otomatis. Harap tutup dengan menggeser ke atas di pengalih multitugas latar belakang untuk menyelesaikan pemuatan. Jika wallpaper tidak muncul, coba reset \"Koleksi Wallpaper\", \"Wallpaper Merkurius\", atau \"Wallpaper Video\" di \"Pengaturan Wallpaper\" di pojok kanan atas."
    static var applyInfo = "Jika setelah membuka editor layar kunci wallpaper yang diimpor tidak terlihat, buka menu pojok kanan atas \"Pengaturan Wallpaper\" dan ketuk \"Reset Koleksi Wallpaper (Collections)\" lalu coba lagi."
    static var imprtFailed = "Pastikan file yang dipilih adalah paket wallpaper .tendies yang valid, lalu coba lagi."
}

struct PosterBoardView: View {
    @AppStorage("pbContainerPath") private var pbContainerPath = ""
    @State private var isReady = false
    @State private var hasContainerAccess = false
    @AppStorage("tendiesArray") private var tendiesArray: [TendiesObject] = []
    @AppStorage("hasShownFirstRunMsg") private var hasShownFirstRunMsg = false
    
    @State private var showImporter = false
    let columns = Array(repeating: GridItem(.flexible()), count: device.userInterfaceIdiom == .pad ? 4 : 2)
    
    var body: some View {
        Group {
            if !isReady {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.25)
                    Text("Sedang mencari jalur kontainer sistem...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    if tendiesArray.isEmpty {
                        Button {
                            showImporter = true
                        } label: {
                            VStack(alignment: .leading) {
                                CompactAlert(title: "Belum ada paket wallpaper yang diimpor", symbol: "exclamationmark.triangle.fill", text: PBMsg.noTendies)
                                    .padding(.horizontal, 15)
                            }
                            .frame(alignment: .leading)
                            .multilineTextAlignment(.leading)
                        }
                    }
                    LazyVGrid(columns: columns) {
                        ForEach($tendiesArray) { $tendies in
                            Button {
                                if !tendies.isOn && tendiesArray.filter({ $0.isOn }).flatMap({ $0.descrNames }).count > 15 {
                                    Alertinator.shared.alert(title: "Batas jumlah wallpaper tercapai!", body: PBMsg.tooManyTendies)
                                } else {
                                    tendies.isOn.toggle()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: tendies.targetDescr == .photos ? "play.rectangle" : "photo")
                                        .imageScale(.large)
                                        .foregroundStyle(Color.accentColor)
                                    VStack {
                                        Text(tendies.name)
                                            .lineLimit(1)
                                            .fontWeight(.medium)
                                        Text("Total \(tendies.descrNames.count) wallpaper")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                                .padding(.vertical, 10)
                                .background {
                                    if tendies.targetDescr == .mercury {
                                        VStack {
                                            Text("M")
                                                .font(.footnote)
                                                .padding(6)
                                                .background(Color.accentColor)
                                                .clipShape(.circle)
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .frame(maxHeight: .infinity)
                                        .padding(12)
                                    }
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 26)
                                        .fill(Color(.secondarySystemBackground))
                                        .overlay {
                                            if tendies.isOn {
                                                RoundedRectangle(cornerRadius: 26)
                                                    .fill(Color.clear)
                                                    .strokeBorder(lineWidth: 2)
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                }
                                .contextMenu {
                                    Button {
                                        let url = AppURL.pbFolders.appendingPathComponent(tendies.folderName)
                                        fsHandlers.openInFilesApp(url)
                                    } label: {
                                        Label("Lihat folder di \"File\"", systemImage: "folder")
                                    }
                                    
                                    Button(role: .destructive) {
                                        withAnimation {
                                            let url = AppURL.pbFolders.appendingPathComponent(tendies.folderName)
                                            try? fm.removeItem(at: url)
                                            tendiesArray.removeAll { $0.id == tendies.id }
                                        }
                                    } label: {
                                        Label("Hapus", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .foregroundStyle(Color(.label))
                }
            }
        }
        .navigationTitle("Wallpaper Layar Kunci Kustom")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                doSetupStuff()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isReady {
                VStack {
                    Button {
                        showImporter = true
                    } label: {
                        ButtonLabel("Impor paket wallpaper .tendies", symbol: "arrow.down.doc")
                    }
                }
                .buttonStyle(ActionButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(device.userInterfaceIdiom == .pad ? 0 : 15)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Impor paket wallpaper .tendies", systemImage: "arrow.down.doc")
                    }
                    .disabled(!isReady)
                    
                    Button {
                        openApp(withBID: SysBID.poster)
                    } label: {
                        Label("Buka PosterBoard", systemImage: "arrow.up.right.square")
                    }
                    
                    Divider()
                    
                    NavigationLink {
                        List {
                            Section {
                                TextField("Jalur kontainer PosterBoard", text: $pbContainerPath, axis: .vertical)
                                    .onChange(of: pbContainerPath) { _, newPath in
                                        let trimmed = newPath.trimmingCharacters(in: .whitespacesAndNewlines)
                                        hasContainerAccess = !trimmed.isEmpty && wq.grantAccess(path: trimmed).0 && fm.fileExists(atPath: trimmed)
                                    }
                                Button("Ambil ulang jalur") {
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        let fetched = fsHandlers.getContainerPath(forMatch: "com.apple.PosterBoard")
                                        let access = !fetched.isEmpty && wq.grantAccess(path: fetched).0 && fm.fileExists(atPath: fetched)
                                        DispatchQueue.main.async {
                                            pbContainerPath = fetched
                                            hasContainerAccess = access
                                        }
                                    }
                                }
                            } header: {
                                HeaderLabel("PosterBoard", symbol: "photo")
                            }
                            
                            Section {
                                Button("Kosongkan daftar yang diimpor") {
                                    for object in tendiesArray {
                                        let url = AppURL.pbFolders.appendingPathComponent(object.folderName)
                                        try? fm.removeItem(at: url)
                                    }
                                    tendiesArray.removeAll()
                                }
                                Button("Reset Koleksi Wallpaper (Collections)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.wpKit)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                                .disabled(!hasContainerAccess || pbContainerPath.isEmpty)
                                Button("Reset Wallpaper Merkurius (MercuryPoster)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.mercury)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                                .disabled(!hasContainerAccess || pbContainerPath.isEmpty)
                                Button("Reset Wallpaper Video (Videos)", role: .destructive) {
                                    let res = resetWallpapers(for: PBPath.photos)
                                    if res {
                                        Haptic.shared.play(.soft)
                                    }
                                }
                                .disabled(!hasContainerAccess || pbContainerPath.isEmpty)
                            } header: {
                                HeaderLabel("Manajemen Data", symbol: "loupe")
                            } footer: {
                                Text("Jika wallpaper kustom tidak tampil dengan benar setelah diterapkan, coba reset cache ekstensi wallpaper dari tipe yang sesuai di atas.")
                            }
                        }
                        .navigationTitle("Pengaturan Wallpaper")
                    } label: {
                        Label("Pengaturan Wallpaper", systemImage: "gearshape")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Terapkan", role: .adaptiveConfirm) {
                    if !hasShownFirstRunMsg {
                        Alertinator.shared.alert(title: "Petunjuk Penggunaan", body: PBMsg.applyInfo, actionLabel: "Lanjutkan", action: {
                            hasShownFirstRunMsg = true
                            proceed()
                        })
                    } else if tendiesArray.filter({ $0.isOn }).flatMap({ $0.descrNames }).count > 5 {
                        Alertinator.shared.alert(title: "Petunjuk Penggunaan", body: PBMsg.limitWarning, actionLabel: "Konfirmasi", action: {
                            proceed()
                        })
                    } else {
                        proceed()
                    }
                    
                    @MainActor
                    func proceed() {
                        let res = applyObjects(tendiesArray.filter { $0.isOn })
                        if !res.0 {
                            if res.1.contains("an item with the same name already exists") || res.1.contains("已经存在") {
                                Alertinator.shared.alert(title: "Gagal menerapkan wallpaper!", body: "Beberapa wallpaper yang dipilih sudah pernah ditambahkan sebelumnya. Jangan tambahkan dua kali.")
                            } else {
                                Alertinator.shared.alert(title: "Gagal menerapkan wallpaper!", body: res.1.isEmpty ? PBMsg.corruption : res.1)
                            }
                        } else {
                            Haptic.shared.play(.soft)
                            Alertinator.shared.alert(title: "Harap mulai ulang PosterBoard untuk menyelesaikan penerapan!", body: PBMsg.finishApply, showCancel: false, actionLabel: "Lanjutkan", action: { openApp(withBID: SysBID.poster) })
                        }
                    }
                }
                .disabled(tendiesArray.filter({ $0.isOn }).isEmpty)
                .disabled(!hasContainerAccess || pbContainerPath.isEmpty || !fm.fileExists(atPath: AppURL.pb.path))
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            let res = handleImport(result)
            if !res {
                Alertinator.shared.alert(title: "Gagal mengimpor paket wallpaper .tendies!", body: PBMsg.imprtFailed)
            }
        }
    }
    
    private func doSetupStuff() {
        var resolvedPath = pbContainerPath
        var accessOK = false
        if !resolvedPath.isEmpty {
            let grant = wq.grantAccess(path: resolvedPath)
            if grant.0 && fm.fileExists(atPath: resolvedPath) {
                accessOK = true
            } else {
                resolvedPath = ""
            }
        }
        if resolvedPath.isEmpty {
            let fetched = fsHandlers.getContainerPath(forMatch: "com.apple.PosterBoard")
            if !fetched.isEmpty {
                resolvedPath = fetched
                let grant = wq.grantAccess(path: resolvedPath)
                accessOK = grant.0 && fm.fileExists(atPath: resolvedPath)
            }
        }
        DispatchQueue.main.async {
            if !resolvedPath.isEmpty {
                pbContainerPath = resolvedPath
            }
            hasContainerAccess = accessOK
            if !accessOK {
                Alertinator.shared.alert(title: "Tidak dapat mengakses kontainer PosterBoard!", body: "Gagal menemukan atau mengotorisasi kontainer com.apple.PosterBoard. Periksa izin atau ambil ulang jalur di \"Pengaturan Wallpaper\" di pojok kanan atas.")
            }
            if !fm.fileExists(atPath: AppURL.pb.path) || !fm.fileExists(atPath: AppURL.pbFolders.path) {
                do {
                    try fm.createDirIfNeeded(at: AppURL.pb)
                    try fm.createDirIfNeeded(at: AppURL.pbFolders)
                } catch {
                    Alertinator.shared.alert(title: "Gagal menginisialisasi direktori wallpaper!", body: AppMsg.opFailed)
                }
            }
            isReady = true
        }
    }
    
    private func applyObjects(_ objects: [TendiesObject]) -> (Bool, String) {
        guard !pbContainerPath.isEmpty else {
            return (false, "Jalur kontainer PosterBoard tidak ditemukan.")
        }
        let rootGrant = wq.grantAccess(path: pbContainerPath)
        if !rootGrant.0 {
            print("(pb) failed to grant access to container root \(pbContainerPath): \(rootGrant.2)")
            return (false, rootGrant.2)
        }
        
        let descrTargets = Set(objects.map(\.targetDescr))
        var resolvedTargetDirs: [PBPath: URL] = [:]
        for descrTarget in descrTargets {
            let relPath = descrTarget.resolvedPath(in: pbContainerPath)
            let targetURL = URL(fileURLWithPath: pbContainerPath).appendingPathComponent(relPath)
            do {
                try fm.createDirectory(at: targetURL, withIntermediateDirectories: true)
            } catch {
                print("(pb) failed to create target directory \(targetURL.path): \(error.localizedDescription)")
                return (false, error.localizedDescription)
            }
            if fm.fileExists(atPath: targetURL.path) {
                let res = wq.grantAccess(path: targetURL.path)
                if !res.0 {
                    print("(pb) failed to grant access at \(targetURL.path): \(res.2)")
                    return (false, res.2)
                }
            }
            resolvedTargetDirs[descrTarget] = targetURL
        }
        
        for object in objects {
            guard let containerURL = resolvedTargetDirs[object.targetDescr] else { continue }
            for descr in object.descrNames {
                let descrURL = AppURL.pbFolders.appendingPathComponent(object.folderName).appendingPathComponent(descr)
                let target = object.targetDescr == .mercury ? containerURL.appendingPathComponent(descrURL.lastPathComponent) : containerURL.appendingPathComponent(UUID().uuidString)
                do {
                    try fm.copyItem(at: descrURL, to: target)
                } catch {
                    print("(pb) failed to copy descriptor (folder: \(object.folderName)): \(error.localizedDescription)")
                    return (false, error.localizedDescription)
                }
            }
        }
        return (true, "")
    }
    
    private func resetWallpapers(for item: PBPath) -> Bool {
        guard !pbContainerPath.isEmpty else {
            Alertinator.shared.alert(title: "Gagal mereset wallpaper!", body: "Jalur kontainer PosterBoard tidak ditemukan.")
            return false
        }
        let rootGrant = wq.grantAccess(path: pbContainerPath)
        if !rootGrant.0 {
            Alertinator.shared.alert(title: "Gagal mereset wallpaper!", body: "Tidak dapat memperoleh izin kontainer PosterBoard: \(rootGrant.2)")
            return false
        }
        let relPath = item.resolvedPath(in: pbContainerPath)
        let target = URL(fileURLWithPath: pbContainerPath).appendingPathComponent(relPath)
        if !fm.fileExists(atPath: target.path) {
            return true
        }
        let targetGrant = wq.grantAccess(path: target.path)
        if !targetGrant.0 {
            Alertinator.shared.alert(title: "Gagal mereset wallpaper!", body: "Tidak dapat memperoleh izin direktori wallpaper target: \(targetGrant.2)")
            return false
        }
        do {
            let contents = try fm.contentsOfDirectory(at: target, includingPropertiesForKeys: nil)
            
            for url in contents {
                try fm.removeItem(at: url)
            }
            return true
        } catch {
            print("(pb) failed to reset \(item.rawValue): \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal mereset wallpaper!", body: error.localizedDescription)
            return false
        }
    }
    
    private func handleImport(_ result: Result<URL, Error>) -> Bool {
        switch result {
        case .success(let fileURL):
            let stopAccess = fileURL.startAccessingSecurityScopedResource()
            defer {
                if stopAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
            }
            if let tendies = pbHandler.makeObjectFromTendies(at: fileURL) {
                withAnimation {
                    tendiesArray.append(tendies)
                }
                return true
            }
            return false
        case .failure(let error):
            print("(pb) failed to import file: \(error.localizedDescription)")
            return false
        }
    }
}
