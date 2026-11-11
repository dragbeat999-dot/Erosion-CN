//
//  GestaltView.swift
//  Erosion
//
//  Created by lunginspector on 8/14/26.
//

import SwiftUI

import UniformTypeIdentifiers

struct GestaltView: View {
    @EnvironmentObject private var mgr: ErosionManager
    @StateObject private var store = GestaltStore.shared
    @AppStorage("mgOverrideGates") private var mgOverrideGates = false
    @AppStorage("mgWriteAtomically") private var mgWriteAtomically = true
    @AppStorage("autoRespring") var autoRespring = false
    @AppStorage("hasShownSheet") private var hasShownSheet = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var mgSubtype = 0
    @State private var mgOgSubtype = 0
    @State private var mgOgDeviceName = ""
    @State private var mgEnableDeviceName = false
    @AppStorage("mgDeviceName") private var mgDeviceName = ""
    @AppStorage("ogMachineName") private var ogMachineName = ""
    @AppStorage("showRegionTweak") private var showRegionTweak = false
    @AppStorage("showCustomKeys") private var showCustomKeys = false
    @AppStorage("mgCustKeyArray") var customKeys: [MGCustomKey] = []
    @State private var mgProductType = ""
    
    @State private var showInfoSheet = false
    @State private var pendingPreviewAfterInfoSheet = false
    @State private var idiotButtonTimerComplete = false
    @State private var mgBaselineDict: NSDictionary = [:]
    @State private var diffPreviewPayload: MGDiffPreviewPayload? = nil
    @State private var showInspectorSheet = false
    @State private var hasLoadedInitialData = false
    @State private var hasPromptedBuildMismatch = false
    @State private var hasWriteAccess = false
    @State private var showBackupImporter = false
    @State private var dualVaultReady = false

    private struct MGDiffPreviewPayload: Identifiable {
        let id = UUID()
        let diffs: [MGDiffItem]
        let candidate: NSMutableDictionary
    }
    
    var body: some View {
        List {
                Section {
                    NavigationLink {
                        MGInspectorView(store: store)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Verifikasi Efek Perangkat Asli dan Probe Slot Dinamis Real-time")
                                    .font(.subheadline.weight(.semibold))
                                Text("Bandingkan cadangan pabrik, konfigurasi saat ini, dan nilai kembalian MGCopyAnswer perangkat asli (read-only murni)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: dualVaultReady ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                            .font(.title3)
                            .foregroundStyle(dualVaultReady ? Color.green : Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dualVaultReady ? "Cadangan Keamanan Pabrik Ganda Terkunci" : "Cadangan Pabrik Lokal Siap")
                                .font(.subheadline.weight(.semibold))
                            Text(dualVaultReady ? "Cadangan sandbox + vault sistem redundansi ganda · SHA-256 telah diverifikasi (tidak hilang saat uninstall/install ulang)" : "Verifikasi integritas SHA-256 dan rollback in-place anti-zero-byte telah diaktifkan")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Button {
                            promptFactoryRestore()
                        } label: {
                            Text("Pulihkan Pabrik Sekali Klik")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.orange)
                        }
                        .buttonStyle(.plain)
                        .disabled(!hasWriteAccess && !weOnADebugBuild)
                    }
                    .padding(.vertical, 2)
                }
                Section {
                    if mgOverrideGates {
                        HStack {
                            Picker("Subtipe Layar", selection: $mgSubtype) {
                                Text("Default Asli (\(mgOgSubtype))").tag(mgOgSubtype)
                                if isDynamIslandHD() && doubleSysVrs() < 19.0 {
                                    Text("Nonaktifkan Dynamic Island").tag(2436)
                                }
                                Text("iPhone 14 Pro").tag(2436)
                                Text("iPhone 14 Pro Max").tag(2796)
                                Text("iPhone 15 Pro Max").tag(2976)
                                if doubleSysVrs() >= 18.0 {
                                    Text("iPhone 16 Pro").tag(2622)
                                    Text("iPhone 16 Pro Max").tag(2868)
                                }
                                if doubleSysVrs() >= 26.0 {
                                    Text("iPhone Air").tag(2736)
                                }
                                if doubleSysVrs() >= 27.0 {
                                    Text("iPhone 18 Pro Max").tag(2670)
                                }
                                if isHomeButtonHD() {
                                    Text("Gestur Layar Penuh iPhone X").tag(2436)
                                }
                            }
                            Spacer()
                            Button {
                                Alertinator.shared.alert(title: "Penjelasan Subtipe Layar", body: MGMsg.subtype)
                            } label: {
                                Image(systemName: "info.circle")
                                    .frame(width: 24, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Toggle("Nama Model Kustom", isOn: $mgEnableDeviceName)
                    if mgEnableDeviceName {
                        TextField("Masukkan nama model kustom", text: $mgDeviceName)
                    }
                    PlainToggle("Render Liquid Glass Hemat Daya (Mode Hemat Baterai)", infoType: .info, infoMessage: MGMsg.liquidGlass, minVrs: 26.0, isOn: store.mgKeyBinding([MGKey.liquidGlassLowPower]))
                } header: {
                    HeaderLabel("Tampilan dan Karakteristik Layar", symbol: "paintbrush.pointed")
                }
                
                if !isDynamIslandHD() || !isAODHD() || !isBootChimeHD() || !isChargeLimitHD() || mgOverrideGates {
                    Section {
                        if !isDynamIslandHD() || mgOverrideGates {
                            PlainToggle("Aktifkan Dynamic Island", minVrs: 19.0, isOn: store.mgKeyBinding([MGKey.island]))
                        }
                        if !isAODHD() || mgOverrideGates {
                            PlainToggle("Aktifkan Always-On Display (AOD)", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.AOD, MGKey.AOTime]))
                            if store.isEnabled([MGKey.AOD]) {
                                PlainToggle("Aktifkan Saturasi Always-On Display", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.AODVibrancy]))
                            }
                        }
                        if !isChargeLimitHD() || mgOverrideGates {
                            PlainToggle("Aktifkan Batas Pengisian 80%", minVrs: 17.0, isOn: store.mgKeyBinding([MGKey.chargeLim]))
                        }
                        if !isBootChimeHD() || mgOverrideGates {
                            PlainToggle("Aktifkan Suara Boot", isOn: store.mgKeyBinding([MGKey.bootChime]))
                        }
                    } header: {
                        HeaderLabel("Buka Fitur Hardware", symbol: "gearshape")
                    }
                }
                
                Section {
                    let internalGateLocked = store.isEnabled([MGKey.appIntell]) || (isAppleIntellHD() && !mgOverrideGates)
                    PlainToggle("Aktifkan Mode Instalasi Internal Apple", infoType: .info, infoMessage: MGMsg.intInstall, isOn: store.mgKeyBinding([MGKey.intInstall]))
                        .disabled(internalGateLocked && !store.isKeyEnabled(MGKey.intInstall))
                    PlainToggle("Aktifkan Penanda Build Internal (Internal Build)", infoType: .info, infoMessage: MGMsg.intBuild, isOn: store.mgKeyBinding([MGKey.intBuild]))
                        .disabled(internalGateLocked && !store.isKeyEnabled(MGKey.intBuild))
                } header: {
                    HeaderLabel("Opsi Debug Internal", symbol: "ant")
                } footer: {
                    if isAppleIntellHD() && !mgOverrideGates {
                        Text("Terkunci otomatis: Mode Instalasi Internal Apple bertentangan dengan Apple Intelligence, mengaktifkannya akan menyebabkan model AI native tidak dapat mengaktifkan Apple Intelligence.")
                    }
                }
                
                Section {
                    AppleIntelligenceCheckupCard(store: store, hasWriteAccess: hasWriteAccess) {
                        Alertinator.shared.runWhenPresentationIdle {
                            showInspectorSheet = true
                        }
                    }

                    PlainToggle("Aktifkan UI Perangkat Riset Keamanan (SRD UI)", minVrs: 26.0, isOn: store.mgKeyBinding([MGKey.srd]))
                    if showRegionTweak || mgOverrideGates || store.mgRegionRestrictionsBinding().wrappedValue {
                        PlainToggle("Buka Batasan Wilayah (AI Tiongkok / Versi AS LL/A)", isOn: store.mgRegionRestrictionsBinding())
                        if store.mgRegionRestrictionsBinding().wrappedValue {
                            HStack(spacing: 10) {
                                Picker("Mode Modifikasi", selection: store.mgRegionUnlockModeBinding()) {
                                    Text("Versi AS Lengkap LL + LL/A").tag(MGRegionUnlockMode.fullUS)
                                    Text("Hanya Ubah Kode Wilayah LL (Pertahankan Akhiran CH/A dan Kompatibilitas Dual-SIM)").tag(MGRegionUnlockMode.regionCodeOnly)
                                }
                                Button {
                                    Alertinator.shared.alert(title: "Penjelasan Mode Modifikasi Wilayah", body: MGMsg.regionModeInfo)
                                } label: {
                                    Image(systemName: "info.circle")
                                        .frame(width: 24, height: 22)
                                }
                                .buttonStyle(.plain)
                            }
                            if store.currentRegionUnlockMode == .fullUS {
                                HStack {
                                    Text("Model Regulasi Versi AS")
                                    Spacer()
                                    TextField("mis. A3473", text: store.mgRegModelBinding())
                                        .multilineTextAlignment(.trailing)
                                        .textInputAutocapitalization(.characters)
                                        .autocorrectionDisabled()
                                }
                            } else {
                                let keptSuffix = store.strVal(forKey: MGKey.regionSysconfig)
                                let keptModel = store.strVal(forKey: MGKey.regModelNumber)
                                HStack {
                                    Text("Akhiran Penjualan dan Model yang Dipertahankan")
                                    Spacer()
                                    Text("\(keptSuffix.isEmpty ? "Pabrik" : keptSuffix) · \(keptModel.isEmpty ? "Pabrik" : keptModel)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    if !isAppleIntellHD() || mgOverrideGates {
                        PlainToggle(
                            "Aktifkan Sakelar Apple Intelligence",
                            subtitle: "Otomatis membuka sinkron fitur \"Hapus\" Foto dan \"Sintesis Tulisan Tangan\" Catatan",
                            infoType: .info,
                            infoTitle: "Penjelasan Mengaktifkan Apple Intelligence",
                            infoMessage: MGMsg.appleIntellInfo,
                            minVrs: 18.1,
                            isOn: store.mgKeyBinding(MGKey.appIntellAllKeys)
                        )
                        .onChange(of: store.mgKeyBinding(MGKey.appIntellAllKeys).wrappedValue) { (_, newVal) in
                            if newVal {
                                store.mgPullKeys([MGKey.intBuild, MGKey.intInstall])
                            }
                        }
                    }
                    if raveSupported() || mgOverrideGates {
                        let advNativeOn = isAdvAppleIntellHD()
                        let advConflictOn = store.isAdvAppleIntellConflictActive()
                        if advNativeOn && !mgOverrideGates {
                            PlainToggle(
                                "Buka Kemampuan AI Lanjutan iOS 27 [Fitur Uji]",
                                subtitle: "✅ Hardware perangkat sudah aktif native (tidak perlu modifikasi tambahan, terkunci anti-salah-matikan)",
                                infoType: .info,
                                infoTitle: "Penjelasan Kemampuan AI Lanjutan iOS 27",
                                infoMessage: MGMsg.advAppleIntell,
                                isOn: .constant(true)
                            )
                            .disabled(true)
                        } else {
                            PlainToggle(
                                "Buka Kemampuan AI Lanjutan iOS 27 [Fitur Uji]",
                                subtitle: advConflictOn
                                    ? "⚠️ Terdeteksi slot eksperimental non-native aktif (akan menyebabkan error hapus \"kualitas tinggi\" foto), harap langsung matikan dan terapkan pemulihan"
                                    : (isNativePersonalTranslatorHD()
                                        ? "✅ Personal Translator native sudah aktif; slot Audio Intelligence eksperimental terkunci nonaktif (memaksa aktif akan menyebabkan error hapus kualitas tinggi foto)"
                                        : "Terkunci otomatis oleh pagar pengaman: memaksa aktif di iPhone/iPad akan menyebabkan error hapus \"kualitas tinggi\" foto"),
                                infoType: .warning,
                                infoTitle: "Penjelasan Kunci Pengaman AI Lanjutan iOS 27",
                                infoMessage: MGMsg.advAppleIntell,
                                isOn: store.mgSafeAdvAppleIntellGuardrailBinding()
                            )
                            .disabled(!advConflictOn)
                        }
                    }
                    if !isAppleIntellHD() || mgOverrideGates {
                        HStack(spacing: 10) {
                            Picker("Penyamaran Model", selection: $mgProductType) {
                                Text("Pertahankan Default").tag(ogMachineName)
                                if ogMachineName.contains("Pad") {
                                    if doubleSysVrs() >= 17.4 {
                                        Text("iPad Pro 11 inci (M4)").tag("iPad16,3")
                                        Text("iPad Pro 11 inci (M4, Cellular)").tag("iPad16,4")
                                    }
                                    Text("iPad Pro 11 inci (Generasi 4)").tag("iPad14,3")
                                    Text("iPad Pro 11 inci (Generasi 4, Cellular)").tag("iPad14,4")
                                } else {
                                    Text("iPhone 15 Pro").tag("iPhone16,1")
                                    Text("iPhone 15 Pro Max").tag("iPhone16,2")
                                    if doubleSysVrs() >= 18.0 {
                                        Text("iPhone 16").tag("iPhone17,3")
                                        Text("iPhone 16 Plus").tag("iPhone17,4")
                                        Text("iPhone 16 Pro").tag("iPhone17,1")
                                        Text("iPhone 16 Pro Max").tag("iPhone17,2")
                                    }
                                    if doubleSysVrs() >= 19.0 {
                                        Text("iPhone 17").tag("iPhone18,3")
                                        Text("iPhone 17 Pro").tag("iPhone18,1")
                                        Text("iPhone 17 Pro Max").tag("iPhone18,2")
                                        Text("iPhone Air").tag("iPhone18,4")
                                    }
                                    if doubleSysVrs() >= 27.0 {
                                        Text("iPhone 18 Pro").tag("iPhone19,2")
                                        Text("iPhone 18 Pro Max").tag("iPhone19,3")
                                        Text("iPhone Duo").tag("iPhone19,4")
                                    }
                                }
                            }
                            Button {
                                Alertinator.shared.alert(title: "Penjelasan Penyamaran Model", body: isAppleIntellHD() ? MGMsg.spoofUseless : MGMsg.spoofAI)
                            } label: {
                                Image(systemName: "info.circle")
                                    .frame(width: 24, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HeaderLabel("Wilayah dan Akses Fitur (Eligibility)", symbol: "flag")
                } footer: {
                    Text("Catatan: Model yang secara native mendukung Apple Intelligence secara default menyembunyikan \"Sakelar Utama Apple Intelligence\" dan \"Penyamaran Model\" yang khusus untuk model lama (model versi Tiongkok hanya perlu mengaktifkan \"Buka Batasan Wilayah\" dan \"Batasan Lapisan Bawah green-tea\" di bawah untuk aktivasi); \"Buka Kemampuan AI Lanjutan iOS 27\" akan menampilkan sakelar atau status native secara real-time sesuai model dan versi firmware saat ini.")
                }

                Section {
                    let greenTeaReady = store.canModifyGreenTeaCache()
                    let wapiReady = store.canModifyWapiCache()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: greenTeaReady ? "checkmark.seal.fill" : "xmark.octagon.fill")
                                .foregroundStyle(greenTeaReady ? Color.green : Color.red)
                            Text(greenTeaReady ? "Layout cache perangkat cocok secara presisi" : "Resolusi dinamis gagal (modifikasi ditolak)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(greenTeaReady ? Color.primary : Color.red)
                            Spacer()
                            Button {
                                let report = MGCacheDataCoordinator.shared.diagnosticReport(for: store.mgCurrentDict)
                                Alertinator.shared.alert(title: "Detail Resolusi Dinamis CacheData Perangkat", body: report)
                            } label: {
                                HStack(spacing: 3) {
                                    Text("Lihat Offset")
                                        .font(.caption)
                                    Image(systemName: "info.circle")
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                        }
                        if let failReason = store.cacheResolutionFailureReason() {
                            Text(failReason)
                                .font(.caption)
                                .foregroundStyle(Color.red)
                        }
                    }
                    .padding(.vertical, 2)

                    PlainToggle(
                        "Buka Batasan Lapisan Bawah Versi Tiongkok (eSIM / Audio FaceTime)",
                        infoType: .info,
                        infoTitle: "Penjelasan Buka Batasan Lapisan Bawah Versi Tiongkok",
                        infoMessage: MGMsg.chinaCacheUnlock,
                        isOn: store.mgChinaRestrictionCacheBinding()
                    )
                    .disabled(!greenTeaReady)

                    PlainToggle(
                        "Tampilkan \"WLAN\" sebagai \"Wi-Fi\"",
                        subtitle: "⚠️ Setelah diaktifkan akan kehilangan fitur \"Tidak Mengizinkan Koneksi Internet\" per aplikasi khas versi Tiongkok",
                        infoType: .warning,
                        infoTitle: "Pemberitahuan Penting WLAN menjadi Wi-Fi",
                        infoMessage: MGMsg.wapiToWifi,
                        isOn: store.mgWapiWifiBinding()
                    )
                    .disabled(!wapiReady)
                } header: {
                    HeaderLabel("Batasan Cache Lapisan Bawah Versi Tiongkok (Resolusi Dinamis CacheData)", symbol: "antenna.radiowaves.left.and.right")
                } footer: {
                    Text("Saat runtime, offset dianalisis real-time dari libMobileGestalt.dylib di memori perangkat dan CacheUUID, panjang, serta bit valid diverifikasi secara ketat; jika resolusi gagal, dilarang keras memodifikasi byte apa pun. Catatan: Mengubah \"WLAN\" menjadi \"Wi-Fi\" akan kehilangan fitur \"Tidak Mengizinkan Koneksi Internet\" versi Tiongkok (hanya menyisakan sakelar data seluler). Harap restart ponsel secara manual setelah menerapkan sakelar grup ini agar berlaku.")
                }

                Section {
                    featureSlotRow(
                        title: "Audio Mix Galeri dan Kamera",
                        subtitle: "Edit video mendukung 4 tingkat mixing vokal: Standar / Isolasi Vokal / Studio / Efek Film",
                        infoTitle: "Penjelasan Audio Mix",
                        infoMessage: MGMsg.audioMixInfo,
                        keys: [MGKey.audioMix]
                    )
                    featureSlotRow(
                        title: "Perekaman Audio Spasial dan Audio Spasial FaceTime",
                        subtitle: "Buka penangkapan audio spasial 3D video kamera dan rendering medan suara spasial FaceTime",
                        infoTitle: "Penjelasan Perekaman Audio Spasial",
                        infoMessage: MGMsg.spatialAudioInfo,
                        keys: MGKey.spatialAudioAllKeys
                    )
                    featureSlotRow(
                        title: "Jepretan Seketika Saat Tombol Rana Ditekan (Responsive Shutter)",
                        subtitle: "Mengurangi latensi pemicu dari penekanan rana kamera ke pipeline imaging, mewujudkan jepretan zero-latency",
                        infoTitle: "Penjelasan Jepretan Seketika",
                        infoMessage: MGMsg.responsiveShutterInfo,
                        keys: [MGKey.responsiveShutter]
                    )
                    featureSlotRow(
                        title: "Mode Evaluasi Tren Hipertensi dan Notifikasi Kesehatan",
                        subtitle: "Mengaktifkan analisis tren tekanan darah tinggi, evaluasi risiko, dan panduan pencatatan pengukuran di aplikasi Kesehatan",
                        infoTitle: "Penjelasan Evaluasi Tren Hipertensi",
                        infoMessage: MGMsg.hypertensionInfo,
                        keys: [MGKey.hypertensionNotif]
                    )
                } header: {
                    HeaderLabel("Kemampuan Lanjutan Imaging dan Kesehatan (Slot Hardware CacheData)", symbol: "waveform.badge.mic")
                } footer: {
                    Text("Kemampuan grup ini dipetakan oleh device tree (IODeviceTree) ke slot boolean biner CacheData, harus ditulis langsung ke CacheData melalui offset slot dinamis untuk melewati pemeriksaan short-circuit validitas _MGCacheSetValueForKey sistem. Kemampuan hardware yang sudah aktif native di perangkat akan otomatis terkunci untuk mencegah degradasi karena kesalahan matikan; harap restart ponsel secara manual setelah diterapkan agar berlaku.")
                }

                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "flask.fill")
                            .foregroundStyle(Color.orange)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Zona Fitur Uji (Experimental · Slot Dinamis CacheData)")
                                .font(.subheadline.weight(.semibold))
                            Text("Kemampuan berikut semuanya dianalisis secara real-time melalui libMobileGestalt.dylib perangkat untuk offset slot boolean biner dan menjalankan verifikasi pra-tulis zero-bootloop. Dipengaruhi oleh perbedaan sensor fisik dan kebijakan eligibilityd antar model, hasil aktual dapat berbeda tergantung perangkat, harap restart perangkat setelah modifikasi untuk menguji.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Button {
                            Alertinator.shared.alert(title: "Penjelasan Fitur Uji", body: MGMsg.expNotice)
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Mute Rana Kamera Asli Versi Jepang/Korea",
                        subtitle: "Menggabungkan modifikasi 3 slot pengecualian suara rana CacheData asli, dapat mencoba mute rana tanpa mengubah ke versi AS",
                        infoTitle: "Mute Rana Kamera Versi Jepang/Korea (Fitur Uji)",
                        infoMessage: MGMsg.expShutterMuteInfo,
                        rules: [
                            MGSlotRule(key: MGKey.shutterRelaxation, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.shutterKeyboardMutePreserve, targetValue: false, required: false),
                            MGSlotRule(key: MGKey.shutterLegacyMutePreserve, targetValue: false, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Penangkapan Mikrofon Ganda High-Low Power Bersamaan (Basis Overdub Studio)",
                        subtitle: "Membuka penanda hardware mikrofon ganda bersamaan yang diperlukan untuk overdub iringan Voice Memos dan pemisahan vokal multitrack",
                        infoTitle: "Mikrofon Ganda High-Low Power Bersamaan (Fitur Uji)",
                        infoMessage: MGMsg.expStudioMicsInfo,
                        rules: [MGSlotRule(key: MGKey.concurrentHPLPMics, targetValue: true)]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Redraw Cahaya Lokal Galeri dan Pemetaan Nada Generasi Baru",
                        subtitle: "Mengaktifkan pipeline render delay mendalam PhotosLocalLight + ToneMapping + HDR",
                        infoTitle: "Peningkatan Cahaya Galeri dan Pemetaan Nada (Fitur Uji)",
                        infoMessage: MGMsg.expPhotoToneInfo,
                        rules: [
                            MGSlotRule(key: MGKey.photosLocalLight, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.toneMapping, targetValue: true, required: false),
                            MGSlotRule(key: MGKey.hdrDeferredProcessing, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Penangkapan Ultra-Wide dan Video Stereo Wide Color Gamut P3",
                        subtitle: "Sinkron mengaktifkan SpatialOverCapture, penangkapan audio video stereo, dan perekaman wide color gamut P3",
                        infoTitle: "Spatial Ultra-Wide dan Video Stereo (Fitur Uji)",
                        infoMessage: MGMsg.expSpatialStereoInfo,
                        rules: [
                            MGSlotRule(key: MGKey.spatialOverCapture, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.stereoAudioRec, targetValue: true, required: false),
                            MGSlotRule(key: MGKey.p3VideoRec, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Panel Lengkap Kontrol Kamera Zoom Geser Kapasitif dan Damping Haptik",
                        subtitle: "Melengkapi 4 slot: kontrol kamera sensitif sentuh kapasitif, damping detent fisik, dan umpan balik haptik halus",
                        infoTitle: "Paket Interaksi Lengkap Kontrol Kamera (Fitur Uji)",
                        infoMessage: MGMsg.expCamControlInfo,
                        rules: [
                            MGSlotRule(key: MGKey.camButton, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.touchSensitiveCamControl, targetValue: true, required: false),
                            MGSlotRule(key: MGKey.hardwareDetents, targetValue: true, required: false),
                            MGSlotRule(key: MGKey.cameraHaptics, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Tampilkan Siklus Baterai dan Tanggal Produksi Model Lama",
                        subtitle: "Menampilkan jumlah siklus dan tanggal penggunaan pertama di \"Tentang Perangkat / Kesehatan Baterai\" model lama",
                        infoTitle: "Detail Kesehatan Baterai Model Lama (Fitur Uji)",
                        infoMessage: MGMsg.expLegacyBatteryInfo,
                        rules: [
                            MGSlotRule(key: MGKey.legacyBatteryInfo, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.legacyDynamicEndOfCharge, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] AOD Kecerahan Tinggi Outdoor dan Frame Buffer Flipbook",
                        subtitle: "Membuka pipeline always-on display HighLuminanceAOD dan Flipbook hemat daya (layar non-LTPO lebih boros daya)",
                        infoTitle: "AOD Kecerahan Tinggi Outdoor (Fitur Uji)",
                        infoMessage: MGMsg.expHighLumAODInfo,
                        rules: [
                            MGSlotRule(key: MGKey.highLuminanceAOD, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.aodFlipbook, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] CarPlay Ultra (Multi-Layar Full LCD Generasi Baru)",
                        subtitle: "Mengaktifkan penanda stack protokol CarPlay 2.0 multi-dashboard generasi baru",
                        infoTitle: "CarPlay Ultra (Fitur Uji)",
                        infoMessage: MGMsg.expCarPlay2Info,
                        rules: [MGSlotRule(key: MGKey.carPlay2, targetValue: true)]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Pipeline Pengiriman Event Sampling Touch 120Hz",
                        subtitle: "Mengaktifkan TouchDelivery120Hz (catatan: layar 60Hz tidak dapat menembus refresh rate fisik)",
                        infoTitle: "Pengiriman Sampling Touch 120Hz (Fitur Uji)",
                        infoMessage: MGMsg.expTouch120Info,
                        rules: [MGSlotRule(key: MGKey.touchDelivery120Hz, targetValue: true)]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Ekualisasi Pendengaran Klinis AirPods dan Mode Alat Bantu Dengar Hemat Daya",
                        subtitle: "Mengaktifkan 3 slot hardware berurutan: ekualisasi hearingaid, audio low-power, dan pengurangan daya",
                        infoTitle: "Pendengaran Klinis dan Mode Alat Bantu Dengar (Fitur Uji)",
                        infoMessage: MGMsg.expHearingAidInfo,
                        rules: [
                            MGSlotRule(key: MGKey.hearingAidEQ, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.hearingAidLE, targetValue: true, required: false),
                            MGSlotRule(key: MGKey.hearingAidPowerRed, targetValue: true, required: false)
                        ]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Deteksi Tren Risiko Sleep Apnea",
                        subtitle: "Mengaktifkan dukungan halaman evaluasi sleep apnea \"Kesehatan -> Gangguan Pernapasan\"",
                        infoTitle: "Deteksi Sleep Apnea (Fitur Uji)",
                        infoMessage: MGMsg.expSleepApneaInfo,
                        rules: [MGSlotRule(key: MGKey.breathingDisturbances, targetValue: true)]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Buka Batasan Paten Software SpO2 Versi AS",
                        subtitle: "Mengatur USLegallyCompliantBloodOxygen menjadi false (model versi Tiongkok secara native tidak dibatasi, tidak perlu diaktifkan)",
                        infoTitle: "Buka Batasan SpO2 Versi AS (Fitur Uji)",
                        infoMessage: MGMsg.expUSBloodOxygenInfo,
                        rules: [MGSlotRule(key: MGKey.usBloodOxygen, targetValue: false)]
                    )

                    experimentalSlotRuleRow(
                        title: "[Fitur Uji] Mode Olahraga Ekstrem Outdoor dan Pemantauan Durasi Paparan Sinar Matahari",
                        subtitle: "Sinkron membuka slot WorkoutUltraMode dan statistik paparan sinar matahari lingkungan",
                        infoTitle: "Olahraga Ekstrem dan Pemantauan Sinar Matahari (Fitur Uji)",
                        infoMessage: MGMsg.expWorkoutUltraInfo,
                        rules: [
                            MGSlotRule(key: MGKey.workoutUltra, targetValue: true, required: true),
                            MGSlotRule(key: MGKey.timeInDaylight, targetValue: true, required: false)
                        ]
                    )

                    PlainToggle(
                        "[Fitur Uji] Routing Siri Hub On-Device dan Dynamic Pruning Model Perintah",
                        subtitle: store.isSiriHubConflictActive()
                            ? "⚠️ Terdeteksi aktif (akan macet di \"Sedang menambahkan konten dukungan Siri\"), harap langsung matikan dan restart untuk pemulihan"
                            : "Terkunci otomatis oleh pagar pengaman: SiriHub adalah routing eksklusif hub rumah, mengaktifkan di iPhone/iPad akan membuat Siri macet",
                        infoType: .warning,
                        infoTitle: "Penjelasan Kunci Pengaman Siri Hub On-Device",
                        infoMessage: MGMsg.expSiriHubInfo,
                        isOn: store.mgSafeSiriHubGuardrailBinding()
                    )
                    .disabled(!store.isSiriHubConflictActive())
                } header: {
                    HeaderLabel("Penggalian Fitur Lapisan Bawah Eksperimental (Fitur Uji)", symbol: "flask")
                } footer: {
                    Text("Semua sakelar bertanda [Fitur Uji] berjalan ketat dalam slot boolean 8-byte CacheData yang telah diverifikasi (zero risiko bootloop), tetapi efek fungsi aktual tergantung coprocessor dan versi sistem perangkat; harap restart ponsel secara manual setelah modifikasi agar berlaku.")
                }
                
                Section {
                    if !isCrashDectHD() || mgOverrideGates {
                        PlainToggle("Item Pengaturan Deteksi Kecelakaan", isOn: store.mgKeyBinding([MGKey.crashDet]))
                    }
                    if !isPWMHD() || mgOverrideGates {
                        PlainToggle("Sakelar Dimming PWM", minVrs: 19.0, isOn: store.mgKeyBinding([MGKey.pwm]))
                    }
                    if ogMachineName.contains("iPhone") || mgOverrideGates {
                        PlainToggle("Item Pengaturan Apple Pencil", isOn: store.mgKeyBinding([MGKey.appPencil]))
                    }
                    if !isCamControlHD() || mgOverrideGates {
                        PlainToggle("Item Pengaturan Tombol Kontrol Kamera", minVrs: 18.0, isOn: store.mgKeyBinding([MGKey.camButton, MGKey.grapPefr]))
                    }
                    if !isActionButtonHD() || mgOverrideGates {
                        PlainToggle("Tombol Aksi (Action Button)", minVrs: 17.0, isOn: store.mgKeyBinding([MGKey.actButton]))
                    }
                    if isHomeButtonHD() || mgOverrideGates {
                        PlainToggle("Ketuk untuk Bangunkan (Tap to Wake)", isOn: store.mgKeyBinding([MGKey.tapToWake]))
                    }
                } header: {
                    HeaderLabel("Panel Preferensi Pengaturan Sistem", symbol: "gear")
                }
                
                if machineName().contains("iPad") || mgOverrideGates {
                    Section {
                        PlainToggle("Aktifkan Stage Manager", isOn: store.mgKeyBinding([MGKey.stageMgr]))
                        if !machineName().contains("iPad") {
                            PlainToggle("Aktifkan Antarmuka dan Split View iPadOS (Dinonaktifkan Permanen oleh Pagar Anti-Bootloop)", infoType: .warning, infoMessage: MGMsg.ipadOS, isOn: store.mgTrollPadBinding())
                                .disabled(!store.mgTrollPadBinding().wrappedValue)
                        }
                    } header: {
                        HeaderLabel("Fitur Multitasking iPadOS", symbol: "ipad")
                    }
                }
            }
            .navigationTitle("MobileGestalt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            store.mgCurrentDict = mgLoadData()
                            Haptic.shared.play(.soft)
                        } label: {
                            Label("Buang Modifikasi Belum Disimpan", systemImage: "arrow.counterclockwise")
                        }
                        
                        Button {
                            promptFactoryRestore()
                        } label: {
                            Label("Pulihkan Cadangan Asli", systemImage: "xmark")
                        }
                        .disabled(!hasWriteAccess && !weOnADebugBuild)
                        
                        Button(role: .destructive) {
                            Alertinator.shared.alert(title: "Yakin ingin sepenuhnya membangun ulang cache MobileGestalt pabrik?", body: MGMsg.mgReset, actionLabel: "Konfirmasi Bangun Ulang", action: {
                                switch mgExecuteCleanCacheRebuild() {
                                case .success:
                                    Alertinator.shared.alert(title: "Cache pabrik siap dibangun ulang!", body: MGMsg.mgResetComp, showCancel: false, actionLabel: "Keluar dan Restart Manual", action: { exitinator() })
                                case .failure(let err):
                                    print("(mg) gagal mereset mobilegestalt: \(err.localizedDescription)")
                                    Alertinator.shared.alert(title: "Gagal membangun ulang cache!", body: err.localizedDescription)
                                }
                            })
                        } label: {
                            Label("Hapus dan Bangun Ulang Cache", systemImage: "trash")
                        }
                        .disabled(!hasWriteAccess && !weOnADebugBuild)
                        
                        Divider()
                        
                        if showCustomKeys {
                            NavigationLink(destination: CustomKeyView()) {
                                Label("Nilai Kunci Kustom", systemImage: "pencil")
                            }
                        }
                        
                        // tweak-specific settings
                        NavigationLink {
                            List {
                                Section {
                                    Button("Ekspor MobileGestalt Saat Ini") {
                                        if let tempURL = makeTemp(MGURL.fsGestaltURL) {
                                            presentShareSheet(with: tempURL)
                                        }
                                    }
                                    Button("Ekspor Cadangan Asli (OriginalGestalt)") {
                                        presentShareSheet(with: MGURL.savedGestaltURL)
                                    }
                                    Button("Impor Cadangan Asli Eksternal (.plist)") {
                                        showBackupImporter = true
                                    }
                                    if fm.fileExists(atPath: MGURL.preApplyGestaltURL.path) {
                                        Button("Ekspor Snapshot Sebelum Tulis Terakhir (PreApply)") {
                                            presentShareSheet(with: MGURL.preApplyGestaltURL)
                                        }
                                    }
                                    Button("Regenerasi Cadangan Asli", role: .destructive) {
                                        Alertinator.shared.alert(title: "Peringatan!", body: MGMsg.mgResetSavWarn, actionLabel: "Konfirmasi Timpa", action: {
                                            try? fm.removeItem(at: MGURL.savedGestaltURL)
                                            try? fm.removeItem(at: MGURL.savedGestaltSHA256URL)
                                            try? fm.removeItem(at: MGURL.systemVaultGestaltURL)
                                            try? fm.removeItem(at: MGURL.systemVaultSHA256URL)
                                            store.mgCurrentDict = mgLoadData()
                                        })
                                    }
                                } header: {
                                    HeaderLabel("Pencadangan dan Ekspor Data", symbol: "loupe")
                                }
                                
                                Section {
                                    PlainToggle("Tampilkan Item Modifikasi Tersembunyi", infoType: .warning, infoMessage: MGMsg.hidTweakWarn, isOn: $mgOverrideGates)
                                    Toggle("Aktifkan Fitur Nilai Kunci Kustom", isOn: $showCustomKeys)
                                    HStack {
                                        Text("Penulisan In-Place Aman + Flush Fisik Disk (F_FULLFSYNC)")
                                        Spacer()
                                        Text("Terkunci Paksa")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack {
                                        Text("Cadangan Redundansi Vault Sistem Lintas Uninstall")
                                        Spacer()
                                        Text(dualVaultReady ? "Tersinkron dan Terkunci" : "Menunggu Sinkronisasi")
                                            .font(.caption)
                                            .foregroundStyle(dualVaultReady ? Color.green : .secondary)
                                    }
                                } footer: {
                                    Text("Protokol keamanan anti-bootloop telah mengunci secara permanen penimpaan in-place tanpa jendela zero-byte (pwrite + F_FULLFSYNC) dan redundansi cadangan ganda vault keamanan tingkat sistem, bahkan jika aplikasi sideload dicabut sertifikat, di-uninstall, dan di-install ulang, cadangan pabrik awal tidak akan hilang.")
                                }
                            }
                            .navigationTitle("Pengaturan Gestalt")
                            .fileImporter(
                                isPresented: $showBackupImporter,
                                allowedContentTypes: [.propertyList],
                                allowsMultipleSelection: false
                            ) { result in
                                switch result {
                                case .success(let urls):
                                    guard let first = urls.first else { return }
                                    switch mgImportExternalOriginalBackup(from: first) {
                                    case .success(let msg):
                                        Haptic.shared.play(.soft)
                                        store.mgCurrentDict = mgLoadData()
                                        Alertinator.shared.alert(title: "Berhasil mengimpor cadangan asli!", body: msg)
                                    case .failure(let err):
                                        Alertinator.shared.alert(title: "Gagal mengimpor cadangan asli!", body: err.localizedDescription)
                                    }
                                case .failure(let err):
                                    Alertinator.shared.alert(title: "Gagal memilih file", body: err.localizedDescription)
                                }
                            }
                        } label: {
                            Label("Pengaturan Lanjutan", systemImage: "gear")
                        }
                    } label: {
                        Label("Menu", systemImage: "ellipsis")
                            .labelStyle(.iconOnly)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terapkan", role: .adaptiveConfirm) {
                        if !hasShownSheet {
                            Alertinator.shared.runWhenPresentationIdle {
                                showInfoSheet = true
                            }
                        } else {
                            prepareApplyPreview()
                        }
                    }
                    .disabled(!hasWriteAccess && !weOnADebugBuild)
                }
            }
            .sheet(isPresented: $showInfoSheet, onDismiss: {
                if pendingPreviewAfterInfoSheet {
                    pendingPreviewAfterInfoSheet = false
                    prepareApplyPreview(isFromSheet: true)
                }
            }) {
                NavigationStack {
                    VStack {
                        InfoSheet(title: "Baca Sebelum Digunakan") {
                            InfoSheetCell(title: "Peringatan Risiko Penting!", symbol: "exclamationmark.triangle.fill", context: MGMsg.support)
                                .modifier(SectionPlatter())
                            InfoSheetCell(title: "Apple Intelligence dan Penyamaran Model", symbol: "apple.intelligence", context: MGMsg.spoofAI)
                            InfoSheetCell(title: "Mode Antarmuka iPadOS", symbol: "ipad", context: MGMsg.ipadOS)
                            InfoSheetCell(title: "Buka Batasan Wilayah (Unlock Versi Tiongkok)", symbol: "map", context: MGMsg.region)
                        } button: {
                            Button(idiotButtonTimerComplete ? "Saya sudah paham, lihat pratinjau perubahan" : "Harap baca peringatan di atas (4 detik)...") {
                                hasShownSheet = true
                                idiotButtonTimerComplete = false
                                pendingPreviewAfterInfoSheet = true
                                showInfoSheet = false
                            }
                            .buttonStyle(ConfirmButtonStyle())
                            .padding(.horizontal, 30)
                            .padding(.bottom, device.userInterfaceIdiom == .pad ? 25 : 0)
                            .disabled(!idiotButtonTimerComplete)
                        }
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            idiotButtonTimerComplete = true
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Batal") {
                                pendingPreviewAfterInfoSheet = false
                                showInfoSheet = false
                                idiotButtonTimerComplete = false
                            }
                        }
                    }
                }
            }
            .sheet(item: $diffPreviewPayload) { payload in
                NavigationStack {
                    List {
                        Section {
                            ForEach(payload.diffs) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.label)
                                        .font(.subheadline.weight(.semibold))
                                    Text(item.keyPath)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("Sebelum:")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(item.beforeText)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("Sesudah:")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Color.accentColor)
                                        Text(item.afterText)
                                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            Text("Total \(payload.diffs.count) perubahan nilai kunci")
                        } footer: {
                            Text("Setelah menekan \"Konfirmasi Tulis\", akan otomatis mencadangkan cache saat ini, mengeksekusi penulisan in-place, dan melakukan verifikasi baca balik lengkap; jika verifikasi anomali akan otomatis rollback file asli.")
                        }
                    }
                    .navigationTitle("Pratinjau Perbandingan Perubahan")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Batal") {
                                diffPreviewPayload = nil
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Konfirmasi Tulis") {
                                let candidate = payload.candidate
                                diffPreviewPayload = nil
                                mgCommit(candidate)
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showInspectorSheet) {
                NavigationStack {
                    MGInspectorView(store: store)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Tutup") {
                                    showInspectorSheet = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                if ogMachineName.isEmpty {
                    ogMachineName = machineName()
                }
                let isWritable = fm.isWritableFile(atPath: MGURL.fsGestaltURL.path)
                if isWritable {
                    hasWriteAccess = true
                } else {
                    let res = wq.grantAccess(path: MGURL.fsGestaltURL.deletingLastPathComponent().path)
                    hasWriteAccess = res.0 || fm.isWritableFile(atPath: MGURL.fsGestaltURL.path)
                    if !hasWriteAccess {
                        Alertinator.shared.alert(title: "Gagal mendapatkan izin tulis MobileGestalt!", body: "Modifikasi tidak akan tersimpan dan berlaku, harap coba restart aplikasi ini dan coba lagi.")
                    }
                }
                if !hasLoadedInitialData {
                    hasLoadedInitialData = true
                    store.mgCurrentDict = mgLoadData()
                } else {
                    dualVaultReady = mgHasSyncedSystemVault()
                }
            }
    }

    @ViewBuilder
    private func featureSlotRow(
        title: String,
        subtitle: String,
        infoTitle: String,
        infoMessage: String,
        keys: [String]
    ) -> some View {
        let canModify = store.canModifyFeatureSlot(keys)
        let isNativeOn = store.isFeatureSlotNativeEnabled(keys)
        if isNativeOn && !mgOverrideGates {
            PlainToggle(
                title,
                subtitle: "✅ Hardware perangkat sudah aktif native (tidak perlu modifikasi tambahan, terkunci anti-salah-matikan)",
                infoType: .info,
                infoTitle: infoTitle,
                infoMessage: infoMessage,
                isOn: .constant(true)
            )
            .disabled(true)
        } else {
            PlainToggle(
                title,
                subtitle: canModify ? subtitle : "Versi sistem saat ini tidak mencakup atau tidak dapat mengurai slot biner ini",
                infoType: .info,
                infoTitle: infoTitle,
                infoMessage: infoMessage,
                isOn: store.mgFeatureSlotBinding(keys)
            )
            .disabled(!canModify)
        }
    }

    @ViewBuilder
    private func experimentalSlotRuleRow(
        title: String,
        subtitle: String,
        infoTitle: String,
        infoMessage: String,
        rules: [MGSlotRule]
    ) -> some View {
        let canModify = store.canModifySlotRules(rules)
        let isNativeSatisfied = store.isSlotRulesNativeSatisfied(rules)
        if isNativeSatisfied && !mgOverrideGates {
            PlainToggle(
                title,
                subtitle: "✅ Default pabrik perangkat sudah memenuhi status target (tidak perlu modifikasi tambahan, terkunci anti-salah-ubah)",
                infoType: .info,
                infoTitle: infoTitle,
                infoMessage: infoMessage,
                isOn: .constant(true)
            )
            .disabled(true)
        } else {
            PlainToggle(
                title,
                subtitle: canModify ? subtitle : "Versi sistem saat ini tidak mencakup atau tidak dapat mengurai slot biner eksperimental ini",
                infoType: .info,
                infoTitle: infoTitle,
                infoMessage: infoMessage,
                isOn: store.mgSlotRulesBinding(rules)
            )
            .disabled(!canModify)
        }
    }

    private func isCurrentGestaltUnmodifiedComparedToOriginal(currentDict: NSDictionary, ogDict: NSDictionary) -> Bool {
        let curExtra = currentDict["CacheExtra"] as? NSDictionary ?? [:]
        let ogExtra = ogDict["CacheExtra"] as? NSDictionary ?? [:]
        let curProd = curExtra[MGKey.prodType] as? String ?? ""
        let ogProd = ogExtra[MGKey.prodType] as? String ?? currentOriginalMachineName()
        if !curProd.isEmpty && curProd != ogProd && curProd != currentOriginalMachineName() {
            return false
        }
        let knownTweakKeys: [String] = [
            MGKey.regionCode,
            MGKey.regionInfo,
            MGKey.regionSysconfig,
            MGKey.regModelNumber,
            MGKey.liquidGlassLowPower,
            MGKey.island,
            MGKey.AOTime,
            MGKey.AOD,
            MGKey.AODVibrancy,
            MGKey.chargeLim,
            MGKey.bootChime,
            MGKey.intInstall,
            MGKey.intBuild,
            MGKey.srd,
            MGKey.crashDet,
            MGKey.pwm,
            MGKey.appPencil,
            MGKey.camButton,
            MGKey.grapPefr,
            MGKey.actButton,
            MGKey.tapToWake,
            MGKey.stageMgr,
            MGKey.modelNameOuter1,
            MGKey.modelNameOuter2
        ] + MGKey.appIntellAllKeys + MGKey.advAppIntellKeys + MGKey.mediaHealthAllKeys + MGKey.experimentalCacheSlotKeys + MGKey.ipadosCacheEx
        for key in knownTweakKeys {
            if !mgPlistValuesEqual(curExtra[key], ogExtra[key]) {
                return false
            }
        }
        if let curArt = curExtra[MGKey.artwork] as? NSDictionary,
           let ogArt = ogExtra[MGKey.artwork] as? NSDictionary {
            if !mgPlistValuesEqual(curArt["ArtworkDeviceSubType"], ogArt["ArtworkDeviceSubType"]) ||
               !mgPlistValuesEqual(curArt["ArtworkDeviceProductDescription"], ogArt["ArtworkDeviceProductDescription"]) {
                return false
            }
        }
        if case .success((let layout, let curData)) = MGCacheDataCoordinator.shared.resolveValidated(for: currentDict),
           let origFlags = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: ogDict) {
            let curGT = curData[layout.greenTeaOffset] == 1
            let curNGT = curData[layout.notGreenTeaOffset] == 1
            if curGT != origFlags.greenTea || curNGT != origFlags.notGreenTea {
                return false
            }
            if let wOff = layout.wapiOffset, let origWapi = origFlags.wapi {
                if (curData[wOff] == 1) != origWapi {
                    return false
                }
            }
            for (fKey, fSlot) in layout.featureSlotIndices where layout.validateSingleBooleanSlot(fSlot, in: curData) {
                if let origVal = origFlags.extraSlots?[fKey], (curData[fSlot * 8] == 1) != origVal {
                    return false
                }
            }
        }
        return true
    }
    
    private func mgLoadData() -> NSMutableDictionary {
        do {
            let mgData = try Data(contentsOf: MGURL.fsGestaltURL)
            let preCheck = mgValidatePlistData(mgData)
            guard preCheck.0 else {
                throw preCheck.1
            }
            let vaultOutcome = try mgEnsureOriginalBackupWithVault(liveData: mgData)
            dualVaultReady = mgHasSyncedSystemVault()
            if vaultOutcome.recoveredFromVault {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    Alertinator.shared.alert(
                        title: "Cadangan pabrik awal berhasil ditemukan otomatis!",
                        body: "Terdeteksi aplikasi pernah di-uninstall dan di-install ulang, telah memulihkan secara lossless cadangan MobileGestalt pabrik awal yang belum dimodifikasi dari vault keamanan sistem (verifikasi SHA-256 lolos)."
                    )
                }
            } else if let dirtyWarn = vaultOutcome.suspectedDirtyWarning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    Alertinator.shared.alert(
                        title: "Pemberitahuan Status Anomali Pencadangan Pertama",
                        body: "\(dirtyWarn)\n\nStatus sistem saat ini telah disimpan sebagai cadangan awal. Jika ingin mendapatkan baseline pabrik 100% murni, dapat memilih \"Hapus dan Bangun Ulang Cache\" di menu kanan atas dan restart, atau impor cadangan pabrik yang Anda simpan sebelumnya di \"Pengaturan Lanjutan\"."
                    )
                }
            }
            
            guard let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
                  let ogCacheExtra = ogDict["CacheExtra"] as? NSDictionary,
                  let ogArtwork = ogCacheExtra[MGKey.artwork] as? NSDictionary else {
                throw "Tidak dapat membaca konfigurasi hardware asli dari MobileGestalt"
            }
            
            mgOgSubtype = ogArtwork["ArtworkDeviceSubType"] as? Int ?? 0
            mgOgDeviceName = ogArtwork["ArtworkDeviceProductDescription"] as? String ?? ""
            
            let ogRegionCode = ogCacheExtra[MGKey.regionCode] as? String ?? ""
            let ogRegionSysconfig = ogCacheExtra[MGKey.regionSysconfig] as? String ?? ""
            let localeRegion = Locale.current.region?.identifier ?? ""
            if ogRegionCode != "LL" || ogRegionSysconfig != "LL/A" || localeRegion != "US" {
                showRegionTweak = true
            }
            
            guard let parsedBaseline = try PropertyListSerialization.propertyList(from: mgData, options: [], format: nil) as? NSDictionary,
                  let currentDict = try PropertyListSerialization.propertyList(from: mgData, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary else {
                throw "Tidak dapat mengurai data dictionary MobileGestalt"
            }
            mgBaselineDict = parsedBaseline
            MGCacheDataCoordinator.shared.recordBaselineIfNeeded(liveDict: currentDict, savedOriginalDict: ogDict)
            if !showRegionTweak,
               case .success((let layout, let curData)) = MGCacheDataCoordinator.shared.resolveValidated(for: currentDict, checkWapiSlot: true) {
                let origFlags = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: ogDict)
                if origFlags?.greenTea == true || origFlags?.wapi == true || (layout.wapiOffset.map { curData[$0] == 1 } ?? false) {
                    showRegionTweak = true
                }
            }
            switch MGCacheDataCoordinator.shared.resolveValidated(for: currentDict) {
            case .success((let layout, _)):
                let wapiDesc = layout.wapiOffset.map { String(format: "0x%X", $0) } ?? "N/A"
                print(String(format: "[*] (mg-cache) Resolusi dinamis perangkat berhasil: UUID=%@, slot=%d (%d byte), green-tea=0x%X, not-green-tea=0x%X, wapi=%@",
                             layout.uuid, layout.slotCount, layout.byteCount, layout.greenTeaOffset, layout.notGreenTeaOffset, wapiDesc))
            case .failure(let err):
                print("[!] (mg-cache) Resolusi dinamis perangkat gagal, modifikasi cache biner terkunci: \(err.localizedDescription)")
            }
            
            if let cacheExtra = currentDict["CacheExtra"] as? NSDictionary,
               let artwork = cacheExtra[MGKey.artwork] as? NSDictionary {
                mgSubtype = artwork["ArtworkDeviceSubType"] as? Int ?? 0
                mgDeviceName = artwork["ArtworkDeviceProductDescription"] as? String ?? ""
                mgEnableDeviceName = (!mgDeviceName.isEmpty && mgDeviceName != mgOgDeviceName)
                mgProductType = cacheExtra[MGKey.prodType] as? String ?? currentOriginalMachineName()
                
                // Detect OS upgrade build mismatch between OriginalGestalt.plist and live MobileGestalt
                let ogBuild = ogDict["CacheVersion"] as? String ?? ""
                let curBuild = currentDict["CacheVersion"] as? String ?? ""
                if !hasPromptedBuildMismatch && !ogBuild.isEmpty && !curBuild.isEmpty && ogBuild != curBuild {
                    hasPromptedBuildMismatch = true
                    if isCurrentGestaltUnmodifiedComparedToOriginal(currentDict: currentDict, ogDict: ogDict) {
                        Alertinator.shared.alert(
                            title: "Terdeteksi versi sistem telah diperbarui",
                            body: "File cadangan asli berasal dari sistem versi lama (\(ogBuild)), sedangkan sistem saat ini telah diperbarui ke \(curBuild) (cache saat ini dalam keadaan pabrik belum dimodifikasi).\n\nDisarankan segera menyinkronkan cadangan asli ke \(curBuild) file pabrik, untuk menghindari penggunaan cadangan versi lama secara tidak sengaja di kemudian hari.",
                            actionLabel: "Perbarui Cadangan Asli",
                            action: {
                                try? mgSaveOriginalBackupWithDigest(mgData)
                                store.mgCurrentDict = mgLoadData()
                            }
                        )
                    } else {
                        print("(mg) notice: savedGestalt CacheVersion (\(ogBuild)) differs from current (\(curBuild))")
                    }
                }
            }
            
            return currentDict
        } catch {
            print("(mg) gagal mendapatkan mobilegestalt: \(error.localizedDescription)")
            Haptic.shared.play(.heavy)
            Alertinator.shared.alert(title: "Gagal membaca MobileGestalt!", body: "Saat ini tidak dapat memuat file konfigurasi dengan normal, harap kembali ke halaman sebelumnya dan periksa log.", showCancel: false, actionLabel: "Kembali", action: { dismiss() })
        }
        
        return [:]
    }
    
    private func buildCandidateDict() throws -> NSMutableDictionary {
        let snapshotData = try PropertyListSerialization.data(fromPropertyList: store.mgCurrentDict, format: .binary, options: 0)
        guard let candidate = try PropertyListSerialization.propertyList(from: snapshotData, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary,
              let cacheExtra = candidate["CacheExtra"] as? NSMutableDictionary else {
            throw "Tidak dapat membangun dictionary CacheExtra yang akan ditulis!"
        }
        guard let artwork = cacheExtra[MGKey.artwork] as? NSMutableDictionary else {
            throw "Terdeteksi field ArtworkTraits (\(MGKey.artwork)) hilang atau bukan struktur dictionary valid, untuk mencegah kehilangan karakteristik layar penulisan diblokir!"
        }
        
        let targetSubtype = mgOverrideGates ? mgSubtype : mgOgSubtype
        if targetSubtype > 0 {
            artwork["ArtworkDeviceSubType"] = targetSubtype
        }
        let trimmedName = mgDeviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if mgEnableDeviceName {
            guard !trimmedName.isEmpty else {
                throw "Nama tidak boleh kosong saat mengaktifkan \"Nama Model Kustom\"!"
            }
            artwork["ArtworkDeviceProductDescription"] = trimmedName
            cacheExtra[MGKey.modelNameOuter1] = trimmedName
            cacheExtra[MGKey.modelNameOuter2] = trimmedName
        } else {
            if !mgOgDeviceName.isEmpty {
                artwork["ArtworkDeviceProductDescription"] = mgOgDeviceName
            }
            for outerKey in [MGKey.modelNameOuter1, MGKey.modelNameOuter2] {
                if let ogVal = store.originalCacheExtraValue(forKey: outerKey) {
                    cacheExtra[outerKey] = ogVal
                } else {
                    cacheExtra.removeObject(forKey: outerKey)
                }
            }
        }
        
        let safeProdType = (!isAppleIntellHD() || mgOverrideGates) ? mgProductType : currentOriginalMachineName()
        if !safeProdType.isEmpty {
            cacheExtra[MGKey.prodType] = safeProdType
        }
        for item in customKeys {
            if let blockedReason = mgIsDangerousCacheExtraKey(item.key) {
                if item.isOn {
                    throw "Kunci kustom \(item.key) telah diblokir oleh pagar anti-bootloop: \(blockedReason)"
                }
                continue
            }
            if item.isOn {
                cacheExtra[item.key] = item.plistValue
            } else if let ogVal = store.originalCacheExtraValue(forKey: item.key) {
                cacheExtra[item.key] = ogVal
            } else {
                cacheExtra.removeObject(forKey: item.key)
            }
        }

        // Self-healing sanitizer: strip non-cached iOS 27 keys and binary CacheData slot keys from CacheExtra
        // in case the device was previously polluted by an older third-party tool before installing Erosion-CN.
        if raveSupported() {
            cacheExtra.removeObject(forKey: MGKey.regionInfo)
            cacheExtra.removeObject(forKey: "0L5PkT61qoH1b/B1USWqjQ")
        }
        for conflictKey in ["iyfxmLogGVIaH7aEgqwcIA", "4snMZS8LJkSctKypt2m+xA", "hiHut/WR+B9Lx/vd0WyeNg", "green-tea", "not-green-tea", "wapi"] + MGKey.advAppIntellKeys + MGKey.mediaHealthAllKeys + MGKey.experimentalCacheSlotKeys {
            cacheExtra.removeObject(forKey: conflictKey)
        }
        return candidate
    }
    
    private func prepareApplyPreview(isFromSheet: Bool = false) {
        do {
            let candidate = try buildCandidateDict()
            if case .failure(let cacheErr) = MGCacheDataCoordinator.shared.validateTransition(from: mgBaselineDict, to: candidate) {
                throw cacheErr.localizedDescription
            }
            let diffs = mgComputeDiff(from: mgBaselineDict, to: candidate)
            if diffs.isEmpty {
                Alertinator.shared.alert(title: "Tidak ada perubahan yang akan diterapkan", body: "Semua konfigurasi saat ini sepenuhnya identik dengan konten file cache sistem, tidak perlu menulis ulang.", showCancel: true)
                return
            }
            let payload = MGDiffPreviewPayload(diffs: diffs, candidate: candidate)
            if diffPreviewPayload != nil {
                diffPreviewPayload = nil
            }
            Alertinator.shared.runWhenPresentationIdle {
                diffPreviewPayload = payload
            }
        } catch {
            Alertinator.shared.alert(title: "Tidak dapat membuat pratinjau perubahan", body: "\(error.localizedDescription)")
        }
    }

    private func mgCommit(_ mgDictToApply: NSMutableDictionary) {
        do {
            let cacheDataChanged = (mgBaselineDict["CacheData"] as? Data) != (mgDictToApply["CacheData"] as? Data)
            let data = try PropertyListSerialization.data(fromPropertyList: mgDictToApply, format: .binary, options: 0)
            let res = mgWriteDetailed(data)
            
            if res.0 {
                print("[*] successfully overwrote and verified mobilegestalt!")
                Haptic.shared.play(.soft)
                store.mgCurrentDict = mgLoadData()
                if autoRespring && !cacheDataChanged {
                    mgr.shouldRespring = true
                } else {
                    let needsRebootHint = store.isEnabled([MGKey.appIntell]) || store.mgRegionRestrictionsBinding().wrappedValue
                    var extraHint = ""
                    if cacheDataChanged {
                        extraHint = "\n\n⚠️ Modifikasi ini mengubah cache biner lapisan bawah (batasan lapisan bawah versi Tiongkok / tampilan Wi-Fi / slot hardware imaging dan kesehatan), muat ulang saja tidak dapat sepenuhnya menyegarkan daemon sistem, harap 【restart ponsel secara manual sekali】 agar berlaku!"
                    } else if needsRebootHint {
                        extraHint = "\n\nJika memodifikasi batasan wilayah atau Apple Intelligence, setelah muat ulang disarankan restart perangkat sekali agar eligibilityd sepenuhnya tersegarkan."
                    }
                    Alertinator.shared.alert(
                        title: "Penulisan dan verifikasi baca balik berhasil!",
                        body: AppMsg.applied + extraHint,
                        actionLabel: "Muat Ulang Sekarang",
                        action: { mgr.shouldRespring = true }
                    )
                }
            } else {
                throw res.1
            }
        } catch {
            print("(mg) gagal menerapkan mobilegestalt: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal menerapkan MobileGestalt!", body: "\(error.localizedDescription)")
        }
    }
    
    private func promptFactoryRestore() {
        Alertinator.shared.alert(
            title: "Konfirmasi pemulihan parameter pabrik perangkat sekali klik?",
            body: MGMsg.revertConfirm,
            actionLabel: "Konfirmasi Pemulihan Pabrik",
            action: {
                mgRevert()
            }
        )
    }

    private func mgRevert() {
        switch mgExecuteFactoryRestore(alsoResetConfigAndKeypad: false) {
        case .restoredSuccessfully(let details):
            print("[*] successfully reverted and verified mobilegestalt!")
            Haptic.shared.play(.soft)
            mgEnableDeviceName = false
            store.mgCurrentDict = mgLoadData()
            Alertinator.shared.alert(
                title: "Parameter pabrik berhasil dipulihkan dan diverifikasi!",
                body: details,
                actionLabel: "Muat Ulang Sekarang",
                action: { mgr.shouldRespring = true }
            )
        case .blockedNeedsCleanRebuild(let title, let reason):
            Alertinator.shared.alert(
                title: title,
                body: reason,
                actionLabel: "Bangun Ulang Cache Pabrik Bersih Sistem",
                action: {
                    switch mgExecuteCleanCacheRebuild(alsoResetConfigAndKeypad: false) {
                    case .success:
                        Alertinator.shared.alert(
                            title: "Cache pabrik siap dibangun ulang!",
                            body: MGMsg.mgResetComp,
                            showCancel: false,
                            actionLabel: "Keluar dan Restart Manual",
                            action: { exitinator() }
                        )
                    case .failure(let err):
                        Alertinator.shared.alert(title: "Gagal membangun ulang cache!", body: err.localizedDescription)
                    }
                }
            )
        case .failed(let reason):
            print("(mg) gagal memulihkan mobilegestalt: \(reason)")
            Alertinator.shared.alert(title: "Gagal memulihkan MobileGestalt!", body: reason)
        }
    }
}

#Preview {
    ContentView()
}
