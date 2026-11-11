//
//  ConfigView.swift
//  Erosion
//
//  Created by lunginspector on 8/21/26.
//

import SwiftUI


enum CNURL {
    static var sharedDevConfig = FSURL.configProfiles.appendingPathComponent("SharedDeviceConfiguration.plist")
    static var cloudConfig = FSURL.configProfiles.appendingPathComponent("CloudConfigurationDetails.plist")
    static var cloudConfigBackup = URL.documentsDirectory.appendingPathComponent("OriginalCloudConfigurationDetails.plist")
}

enum CNMsg {
    static var supWarning = "Memaksa penulisan IsSupervised=true pada perangkat iOS ritel pribadi sangat mudah memicu loop tak terbatas wizard manajemen jarak jauh Setup.app (Setup Assistant Loop / deadlock 403) bahkan hingga tidak bisa masuk ke layar utama! Pagar pengaman anti-bootloop telah menonaktifkan secara permanen opsi pengaktifan mode supervisi; jika sebelumnya pernah tidak sengaja diaktifkan melalui versi lama atau alat lain, Anda dapat membersihkannya secara terpisah melalui \"Pemeriksaan Deadlock Sisa Pseudo-Supervisi\" di bawah."
    static var resetInfo = "Setelah menekan \"Konfirmasi\", teks bagian bawah layar kunci dan plat nama aset perangkat akan dihapus dengan aman, serta profil konfigurasi supervisi sisa akan dipulihkan atau dibersihkan."
    static var assetTagInfo = "[Fitur Uji] AssetTagInformation adalah field plat nama aset bawaan dalam profil konfigurasi sistem, dapat menampilkan kontak anti-kehilangan atau nomor perangkat di bagian bawah layar kunci atau di Tentang Perangkat, tanpa memodifikasi biner sistem atau penanda supervisi apa pun."
}

private enum CloudConfigAuditState {
    case clean
    case genuineMDM(org: String)
    case fakeSupervisionResidue(org: String)
}

struct ConfigView: View {
    @EnvironmentObject private var mgr: ErosionManager
    @AppStorage("autoRespring") var autoRespring = false
    @State private var ftCurrentDict = NSMutableDictionary()
    @State private var ccCurrentDict = NSMutableDictionary()
    @State private var footnoteText = ""
    @State private var assetTagText = ""
    @State private var supervised = false
    @State private var orgName = ""
    @State private var hasAccess = false
    @State private var auditState: CloudConfigAuditState = .clean
    
    var body: some View {
        List {
                Section {
                    VStack(spacing: 14) {
                        HStack {
                            Image(systemName: "flashlight.off.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding()
                                .modifier(QuickActionBackground())
                            Spacer()
                            Image(systemName: "camera.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 26, height: 26)
                                .padding()
                                .modifier(QuickActionBackground())
                        }
                        .padding(.horizontal, 35)
                        
                        VStack(spacing: 2) {
                            if !assetTagText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(assetTagText)
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Text(footnoteText)
                                .font(.system(size: 9))
                                .frame(height: 10)
                            Capsule()
                                .frame(width: 145, height: 4)
                        }
                    }
                    .padding(.top, 25)
                    .padding(.bottom, 10)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(
                        Group {
                            Image("solarium")
                                .resizable()
                                .scaledToFill()
                                .offset(y: 10)
                        }
                    )
                    
                    TextField("Teks kustom bagian bawah layar kunci (LockScreenFootnote)", text: $footnoteText)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("[Fitur Uji] Plat Nama Aset Perangkat Layar Kunci")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button {
                                Alertinator.shared.alert(title: "Plat Nama Aset Perangkat Layar Kunci [Fitur Uji]", body: CNMsg.assetTagInfo)
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        TextField("Masukkan telepon/email anti-kehilangan atau nomor aset (AssetTagInformation)", text: $assetTagText)
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            Button("Isi Template Anti-Kehilangan") {
                                assetTagText = "Jika ditemukan harap hubungi pemilik · Terima kasih telah mengembalikan"
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            Button("Isi Identitas Perangkat") {
                                assetTagText = "\(UIDevice.current.name) · iOS \(UIDevice.current.systemVersion)"
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)

                            if !assetTagText.isEmpty {
                                Button("Kosongkan", role: .destructive) {
                                    assetTagText = ""
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    HeaderLabel("Ekstensi Plat Nama Anti-Kehilangan (Fitur Uji)", symbol: "tag")
                } footer: {
                    Text("Menulis field AssetTagInformation ke SharedDeviceConfiguration.plist, biarkan kosong lalu tekan \"Terapkan\" di kanan atas untuk menghapusnya.")
                }
                
                Section {
                    PlainToggle("Aktifkan Mode Supervisi (Pagar anti-loop wizard pengaturan telah dikunci)", infoType: .warning, infoTitle: "Penjelasan Perlindungan Mode Supervisi", infoMessage: CNMsg.supWarning, isOn: $supervised)
                        .disabled(true)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: auditIconName)
                                .foregroundStyle(auditAccentColor)
                            Text("[Fitur Uji] Pemeriksaan Deadlock Sisa Pseudo-Supervisi")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(auditBadgeText)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(auditAccentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(auditAccentColor)
                        }
                        Text(auditDetailText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if case .fakeSupervisionResidue = auditState {
                            Button(role: .destructive) {
                                cleanFakeSupervisionOnly()
                            } label: {
                                Label("Bersihkan Sisa Pseudo-Supervisi dengan Aman Sekali Klik (Pertahankan Teks Layar Kunci)", systemImage: "shield.lefthalf.filled.badge.checkmark")
                                    .font(.footnote.weight(.medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 3)
                } header: {
                    HeaderLabel("Pengaturan Supervisi dan Pemeriksaan Keamanan (Fitur Uji)", symbol: "eye")
                }
            }
            .navigationTitle("Konfigurasi Sistem dan Supervisi")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Alertinator.shared.alert(title: "Yakin ingin mengatur ulang modifikasi konfigurasi?", body: CNMsg.resetInfo, actionLabel: "Konfirmasi", action: {
                            reset()
                        })
                    } label: {
                        Label("Pulihkan Default", systemImage: "gobackward")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!hasAccess)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terapkan", role: .adaptiveConfirm) {
                        apply()
                    }
                    .disabled(!hasAccess)
                }
            }
            .onAppear {
                doSetup()
            }
    }
    
    private static func isGenuineMDMCloudConfig(_ dict: NSDictionary) -> Bool {
        let mdmKeys = [
            "ConfigurationSource",
            "PostSetupProfileWasInstalled",
            "AwaitDeviceConfigured",
            "CloudConfigurationUIComplete",
            "ConfigurationURL",
            "AnchorCertificates",
            "SupervisorHostCertificates"
        ]
        for key in mdmKeys where dict[key] != nil {
            return true
        }
        let allKeys = Set(dict.allKeys.compactMap { $0 as? String })
        let fakeOnlyKeys: Set<String> = ["IsSupervised", "OrganizationName"]
        return !allKeys.subtracting(fakeOnlyKeys).isEmpty
    }
    
    private func doSetup() {
        if fm.isWritableFile(atPath: FSURL.configProfiles.path) {
            hasAccess = true
        } else {
            let res = wq.grantAccess(path: FSURL.configProfiles.path)
            hasAccess = res.0
            if !res.0 {
                Alertinator.shared.alert(title: "Gagal mendapatkan izin tulis!", body: AppMsg.opFailed)
                return
            }
        }
        if UserDefaults.standard.object(forKey: "cn_cloud_config_originally_existed") == nil {
            var genuineExisted = false
            if fm.fileExists(atPath: CNURL.cloudConfig.path),
               let existingDict = NSDictionary(contentsOf: CNURL.cloudConfig),
               Self.isGenuineMDMCloudConfig(existingDict) {
                genuineExisted = true
            }
            UserDefaults.standard.set(genuineExisted, forKey: "cn_cloud_config_originally_existed")
            if genuineExisted && !fm.fileExists(atPath: CNURL.cloudConfigBackup.path) {
                try? fm.copyItem(at: CNURL.cloudConfig, to: CNURL.cloudConfigBackup)
                mgExcludeFromCloudBackup(CNURL.cloudConfigBackup)
            }
        }
        loadData()
    }
    
    private var auditIconName: String {
        switch auditState {
        case .clean: return "checkmark.shield.fill"
        case .genuineMDM: return "building.2.crop.circle.fill"
        case .fakeSupervisionResidue: return "exclamationmark.triangle.fill"
        }
    }

    private var auditAccentColor: Color {
        switch auditState {
        case .clean: return .green
        case .genuineMDM: return .blue
        case .fakeSupervisionResidue: return .red
        }
    }

    private var auditBadgeText: String {
        switch auditState {
        case .clean: return "Aman Tanpa Sisa"
        case .genuineMDM: return "MDM Perusahaan Sah"
        case .fakeSupervisionResidue: return "Sisa Pseudo-Supervisi Berisiko Tinggi"
        }
    }

    private var auditDetailText: String {
        switch auditState {
        case .clean:
            return "Tidak terdeteksi file CloudConfigurationDetails.plist palsu, pembaruan sistem atau restart tidak akan memicu loop tak terbatas wizard manajemen jarak jauh Setup Assistant 403."
        case .genuineMDM(let org):
            let displayOrg = org.isEmpty ? "Perusahaan/Institusi Pendidikan" : org
            return "Terdeteksi konfigurasi MDM sah dengan anchor sertifikat lengkap (\(displayOrg)), pagar anti-bootloop telah otomatis melindungi file asli ini agar tidak terhapus secara tidak sengaja."
        case .fakeSupervisionResidue(let org):
            let suffix = org.isEmpty ? "" : " (nama organisasi sisa: \(org))"
            return "Terdeteksi file pseudo-supervisi pihak ketiga yang hanya berisi IsSupervised/OrganizationName tanpa rantai sertifikat MDM\(suffix)! Sangat mudah memicu deadlock 403 wizard aktivasi setelah pembaruan OTA, disarankan segera tekan tombol di bawah untuk membersihkannya."
        }
    }

    private func loadData() {
        if fm.fileExists(atPath: CNURL.sharedDevConfig.path),
           let ftDict = NSMutableDictionary(contentsOf: CNURL.sharedDevConfig) {
            ftCurrentDict = ftDict
            footnoteText = ftDict["LockScreenFootnote"] as? String ?? ""
            assetTagText = ftDict["AssetTagInformation"] as? String ?? ""
        } else {
            ftCurrentDict = NSMutableDictionary()
            footnoteText = ""
            assetTagText = ""
        }
        if fm.fileExists(atPath: CNURL.cloudConfig.path),
           let ccDict = NSMutableDictionary(contentsOf: CNURL.cloudConfig) {
            ccCurrentDict = ccDict
            supervised = ccDict["IsSupervised"] as? Bool ?? false
            orgName = ccDict["OrganizationName"] as? String ?? ""
            if Self.isGenuineMDMCloudConfig(ccDict) {
                auditState = .genuineMDM(org: orgName)
            } else {
                auditState = .fakeSupervisionResidue(org: orgName)
            }
        } else {
            ccCurrentDict = NSMutableDictionary()
            supervised = false
            orgName = ""
            auditState = .clean
        }
    }

    private func cleanFakeSupervisionOnly() {
        do {
            guard fm.fileExists(atPath: CNURL.cloudConfig.path),
                  let currentDict = NSDictionary(contentsOf: CNURL.cloudConfig),
                  !Self.isGenuineMDMCloudConfig(currentDict) else {
                loadData()
                return
            }
            try fm.removeItem(at: CNURL.cloudConfig)
            try? fm.removeItem(at: CNURL.cloudConfigBackup)
            UserDefaults.standard.set(false, forKey: "cn_cloud_config_originally_existed")
            Haptic.shared.play(.soft)
            loadData()
            Alertinator.shared.alert(
                title: "Sisa pseudo-supervisi berhasil dibersihkan!",
                body: "Telah dengan aman menghapus CloudConfigurationDetails.plist palsu dan mempertahankan konfigurasi teks bagian bawah layar kunci serta plat nama aset Anda.\n\(AppMsg.applied)",
                actionLabel: "Muat Ulang Sekarang",
                action: { mgr.shouldRespring = true }
            )
        } catch {
            Alertinator.shared.alert(title: "Gagal membersihkan sisa pseudo-supervisi!", body: error.localizedDescription)
        }
    }
    
    private func apply() {
        let ftDict = NSMutableDictionary(dictionary: ftCurrentDict)
        let trimmedFootnote = footnoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAssetTag = assetTagText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedFootnote.isEmpty {
            ftDict.removeObject(forKey: "LockScreenFootnote")
        } else {
            ftDict["LockScreenFootnote"] = footnoteText
        }

        if trimmedAssetTag.isEmpty {
            ftDict.removeObject(forKey: "AssetTagInformation")
        } else {
            ftDict["AssetTagInformation"] = trimmedAssetTag
        }

        do {
            try fm.createDirectory(at: FSURL.configProfiles, withIntermediateDirectories: true)
            if ftDict.count == 0 {
                if fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
                    try fm.removeItem(at: CNURL.sharedDevConfig)
                }
            } else {
                let ftData = try PropertyListSerialization.data(fromPropertyList: ftDict, format: .binary, options: 0)
                if fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
                    let res = writeFileAtomically(ftData, to: CNURL.sharedDevConfig)
                    if !res.0 {
                        throw res.1
                    }
                } else {
                    try ftData.write(to: CNURL.sharedDevConfig, options: .atomic)
                }
            }
            ftCurrentDict = ftDict
            print("(cn) berhasil menerapkan tweak footnote & asset tag dengan aman!")
            Haptic.shared.play(.soft)
            if autoRespring {
                mgr.shouldRespring = true
            } else {
                Alertinator.shared.alert(title: "Modifikasi konfigurasi sistem berhasil diterapkan!", body: AppMsg.applied, actionLabel: "Muat Ulang Sekarang", action: { mgr.shouldRespring = true })
            }
        } catch {
            print("(cn) gagal menulis file konfigurasi: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal menerapkan modifikasi!", body: "\(error.localizedDescription)")
        }
    }
    
    static func resetSystemConfigSafely() throws {
        if !fm.isWritableFile(atPath: FSURL.configProfiles.path) {
            _ = wq.grantAccess(path: FSURL.configProfiles.path)
        }
        if fm.fileExists(atPath: CNURL.sharedDevConfig.path) {
            try fm.removeItem(at: CNURL.sharedDevConfig)
        }
        let originallyExisted = UserDefaults.standard.bool(forKey: "cn_cloud_config_originally_existed")
        if originallyExisted,
           fm.fileExists(atPath: CNURL.cloudConfigBackup.path),
           let backupDict = NSDictionary(contentsOf: CNURL.cloudConfigBackup),
           Self.isGenuineMDMCloudConfig(backupDict) {
            let backupData = try Data(contentsOf: CNURL.cloudConfigBackup)
            if fm.fileExists(atPath: CNURL.cloudConfig.path) {
                let res = writeFileAtomically(backupData, to: CNURL.cloudConfig)
                if !res.0 { throw res.1 }
            } else {
                try backupData.write(to: CNURL.cloudConfig, options: .atomic)
            }
        } else if fm.fileExists(atPath: CNURL.cloudConfig.path) {
            if let currentDict = NSDictionary(contentsOf: CNURL.cloudConfig),
               !Self.isGenuineMDMCloudConfig(currentDict) {
                // Remove fake supervision plist left by older Erosion versions (SEC-M4-01)
                try fm.removeItem(at: CNURL.cloudConfig)
                try? fm.removeItem(at: CNURL.cloudConfigBackup)
                UserDefaults.standard.set(false, forKey: "cn_cloud_config_originally_existed")
            } else if !originallyExisted {
                try fm.removeItem(at: CNURL.cloudConfig)
            }
        }
    }

    private func reset() {
        do {
            try Self.resetSystemConfigSafely()
            print("(cn) berhasil mengatur ulang tweak konfigurasi!")
            Haptic.shared.play(.soft)
            loadData()
            footnoteText = ""
            assetTagText = ""
            Alertinator.shared.alert(title: "Modifikasi konfigurasi sistem berhasil diatur ulang!", body: AppMsg.applied, actionLabel: "Muat Ulang Sekarang", action: { mgr.shouldRespring = true })
        } catch {
            print("(cn) gagal mengatur ulang file konfigurasi: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal mengatur ulang modifikasi!", body: "\(error.localizedDescription)")
        }
    }
}

// MARK: ui
struct QuickActionBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 19.0, *) {
            content
                .glassEffect(.clear.interactive(), in: .circle)
        } else {
            content
                .background(.ultraThinMaterial, in: .circle)
        }
    }
}
