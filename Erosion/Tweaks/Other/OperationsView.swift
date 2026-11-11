//
//  OperationsView.swift
//  Erosion
//
//  Created by lunginspector on 8/17/26.
//

import SwiftUI
import UniformTypeIdentifiers


struct OperationsView: View {
    @State private var directory = ""
    @State private var fileName = ""
    @State private var isAcc = false
    @State private var showImporter = false
    
    @State private var imprtName = ""
    @State private var imprtData = Data()
    
    private var normalizedDirectory: String {
        var dir = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        while dir.count > 1 && dir.hasSuffix("/") {
            dir.removeLast()
        }
        return dir
    }
    
    private var normalizedFileName: String {
        var name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        while name.hasPrefix("/") {
            name.removeFirst()
        }
        while name.hasSuffix("/") {
            name.removeLast()
        }
        return name
    }
    
    var body: some View {
        List {
            Section {
                TextField("Path direktori target (mis. /var/...)", text: $directory)
                    .disabled(isAcc)
                TextField("Nama file target", text: $fileName)
                    .disabled(isAcc)
                HStack {
                    Button("Dapatkan izin baca/tulis") {
                        let cleanDir = normalizedDirectory
                        let cleanFile = normalizedFileName
                        directory = cleanDir
                        fileName = cleanFile
                        guard !cleanDir.isEmpty else {
                            Alertinator.shared.alert(title: "Path direktori kosong!", body: "Masukkan path direktori target yang valid terlebih dahulu.")
                            return
                        }
                        let dirRes = wq.grantAccess(path: cleanDir)
                        if !dirRes.0 {
                            Alertinator.shared.alert(title: "Gagal mendapatkan izin direktori target!", body: "\(dirRes.1): \(dirRes.2)")
                            return
                        }
                        if !cleanFile.isEmpty {
                            let fullPath = "\(cleanDir)/\(cleanFile)"
                            if fm.fileExists(atPath: fullPath) {
                                let fileRes = wq.grantAccess(path: fullPath)
                                if !fileRes.0 {
                                    Alertinator.shared.alert(title: "Gagal mendapatkan izin file target!", body: "\(fileRes.1): \(fileRes.2)")
                                    return
                                }
                            }
                        }
                        isAcc = true
                    }
                    .disabled(isAcc || normalizedDirectory.isEmpty)
                    if isAcc {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Sudah diizinkan")
                        }
                        .foregroundStyle(.green)
                    }
                }
                if isAcc {
                    Button("Ubah path target", role: .destructive) {
                        isAcc = false
                        imprtName = ""
                        imprtData = Data()
                    }
                    
                    Button("Ekspor file asli") {
                        let fileDir = "\(normalizedDirectory)/\(normalizedFileName)"
                        if let tempURL = makeTemp(URL(fileURLWithPath: fileDir)) {
                            presentShareSheet(with: tempURL)
                        } else {
                            Alertinator.shared.alert(title: "Gagal mengekspor file asli!", body: "Tidak dapat membaca atau menyalin file target. Pastikan nama file target ada dan dapat dibaca.")
                        }
                    }
                    .disabled(normalizedFileName.isEmpty)
                }
            } header: {
                HeaderLabel("File Target", symbol: "dot.scope")
            }
            
            Section {
                HStack {
                    Button(imprtData.isEmpty ? "Impor file pengganti" : "Pilih ulang file pengganti") {
                        showImporter = true
                    }
                    if !imprtName.isEmpty {
                        Spacer()
                        Text(imprtName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Button("Timpa file target") {
                    let targetURL = URL(fileURLWithPath: normalizedDirectory).appendingPathComponent(normalizedFileName).standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "Penimpaan path sistem berisiko tinggi diblokir!", body: blockReason)
                        return
                    }
                    do {
                        Self.backupBeforeMutation(targetURL)
                        if fm.fileExists(atPath: targetURL.path) {
                            let atomicRes = writeFileAtomically(imprtData, to: targetURL)
                            if !atomicRes.0 {
                                throw atomicRes.1
                            }
                        } else {
                            try imprtData.write(to: targetURL, options: .atomic)
                        }
                        print("(ov) successfully overwrote file: \(targetURL.path) (\(imprtData.count))")
                        Haptic.shared.play(.soft)
                    } catch {
                        print("(ov) failed to overwrite: \(error.localizedDescription)")
                        Alertinator.shared.alert(title: "Gagal menimpa file!", body: "\(error.localizedDescription)")
                    }
                }
                .disabled(!isAcc || imprtData.isEmpty || normalizedFileName.isEmpty)
                
                Button("Tulis ke direktori target") {
                    let targetURL = URL(fileURLWithPath: normalizedDirectory).appendingPathComponent(imprtName).standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "Penulisan ke path sistem berisiko tinggi diblokir!", body: blockReason)
                        return
                    }
                    do {
                        Self.backupBeforeMutation(targetURL)
                        if fm.fileExists(atPath: targetURL.path) {
                            let atomicRes = writeFileAtomically(imprtData, to: targetURL)
                            if !atomicRes.0 {
                                throw atomicRes.1
                            }
                        } else {
                            try imprtData.write(to: targetURL, options: .atomic)
                        }
                        print("(ov) successfully moved file: \(imprtName) -> \(targetURL.path)")
                        Haptic.shared.play(.soft)
                    } catch {
                        print("(ov) failed to move: \(error.localizedDescription)")
                        Alertinator.shared.alert(title: "Gagal menulis file!", body: "\(error.localizedDescription)")
                    }
                }
                .disabled(!isAcc || imprtData.isEmpty)
                
                Button("Hapus file target", role: .destructive) {
                    let targetURL = URL(fileURLWithPath: normalizedDirectory).appendingPathComponent(normalizedFileName).standardizedFileURL
                    if let blockReason = Self.blockedSystemPathReason(for: targetURL) {
                        Alertinator.shared.alert(title: "Penghapusan file sistem berisiko tinggi diblokir!", body: blockReason)
                        return
                    }
                    Alertinator.shared.alert(
                        title: "Konfirmasi hapus file target?",
                        body: "Sebelum dihapus, cadangan bertanda waktu akan disimpan otomatis di direktori dokumen aplikasi:\n\(targetURL.path)",
                        actionLabel: "Konfirmasi Hapus",
                        action: {
                            do {
                                Self.backupBeforeMutation(targetURL)
                                try fm.removeItem(at: targetURL)
                                print("(ov) successfully deleted file: \(targetURL.path)")
                                Haptic.shared.play(.heavy)
                            } catch {
                                print("(ov) failed to delete: \(error.localizedDescription)")
                                Alertinator.shared.alert(title: "Gagal menghapus file!", body: "\(error.localizedDescription)")
                            }
                        }
                    )
                }
                .disabled(!isAcc || normalizedFileName.isEmpty)
            } header: {
                HeaderLabel("Operasi File", symbol: "wrench.and.screwdriver")
            }
        }
        .navigationTitle("Penggantian File Bebas")
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item]) { result in
            handleImport(result)
        }
    }
    
    func handleImport(_ res: Result<URL, Error>) {
        switch res {
        case .success(let recURL):
            do {
                let stopAccess = recURL.startAccessingSecurityScopedResource()
                defer {
                    if stopAccess {
                        recURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                imprtData = try Data(contentsOf: recURL)
                imprtName = recURL.lastPathComponent
            } catch {
                print("(ov) failed to import file: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "Gagal mengimpor file!", body: "File ini mungkin tidak valid, rusak, atau tidak dapat diakses. Coba gunakan file pengganti lain.")
            }
        case .failure(let error):
            print("(ov) failed to import file: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal mengimpor file!", body: "File ini mungkin tidak valid, rusak, atau tidak dapat diakses. Coba gunakan file pengganti lain.")
        }
    }

    private static func blockedSystemPathReason(for url: URL) -> String? {
        let p = url.standardizedFileURL.path
        let lower = p.lowercased()
        let exactNames: Set<String> = [
            "com.apple.mobilegestalt.plist",
            "cloudconfigurationdetails.plist",
            "keychain-2.db",
            "truststore.sqlite3"
        ]
        if exactNames.contains(url.lastPathComponent.lowercased()) {
            return "File \(url.lastPathComponent) termasuk konfigurasi keamanan/boot inti sistem. Dilarang keras menulis atau menghapusnya secara langsung lewat “Penggantian File Bebas” (gunakan modul khusus atau menu aman)."
        }
        let forbiddenPrefixes = [
            "/system", "/private/preboot", "/usr", "/bin", "/sbin", "/dev",
            "/var/keychains", "/private/var/keychains", "/var/db", "/private/var/db"
        ]
        for pre in forbiddenPrefixes where lower == pre || lower.hasPrefix(pre + "/") {
            return "Path \(p) berada di zona perlindungan inti sistem. Pengaman anti-white-Apple melarang penimpaan atau penghapusan langsung."
        }
        return nil
    }

    private static func backupBeforeMutation(_ url: URL) {
        guard fm.fileExists(atPath: url.path) else { return }
        let backupDir = URL.documentsDirectory.appendingPathComponent("OperationBackups")
        try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        mgExcludeFromCloudBackup(backupDir)
        let stamp = Int(Date().timeIntervalSince1970)
        let backupURL = backupDir.appendingPathComponent("\(stamp)_\(url.lastPathComponent).bak")
        try? fm.copyItem(at: url, to: backupURL)
        mgExcludeFromCloudBackup(backupURL)
    }
}
