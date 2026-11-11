//
//  MGInspectorView.swift
//  Erosion
//
//  Read-only live MobileGestalt MGCopyAnswer verifier, dynamic CacheData slot inspector,
//  and Apple Intelligence 4-Factor readiness checkup panel.
//

import SwiftUI

// MARK: - Feature 2: Apple Intelligence 4-Factor Readiness Checkup Card

struct AppleIntelligenceCheckupCard: View {
    @ObservedObject var store: GestaltStore
    var hasWriteAccess: Bool = true
    var onOpenInspector: () -> Void

    private struct FactorItem: Identifiable {
        let id: String
        let title: String
        let detail: String
        let isReady: Bool
        let isLiveActive: Bool
    }

    private var expectedUSModel: String {
        let hwProd = originalHardwareProductType()
        let ogReg = (store.originalCacheExtraValue(forKey: MGKey.regModelNumber) as? String) ?? ""
        return usRegulatoryModelNumber(productType: hwProd, originalRegModel: ogReg) ?? "A3473"
    }

    private var factors: [FactorItem] {
        // 1. RegionCode & RegionInfoFromSysconfig
        let stagedRegCode = (store.cacheExtra[MGKey.regionCode] as? String) ?? ""
        let stagedSysconfig = (store.cacheExtra[MGKey.regionSysconfig] as? String) ?? ""
        let ogRegCode = (store.originalCacheExtraValue(forKey: MGKey.regionCode) as? String) ?? stagedRegCode
        let isNativeNonRestrictedRegion = !ogRegCode.isEmpty && ogRegCode != "CH" && ogRegCode != "ZA"
        let isLLOnlyMode = (stagedRegCode == "LL" && stagedSysconfig != "LL/A")
        let regionReady = (stagedRegCode == "LL") || (isNativeNonRestrictedRegion && stagedRegCode != "CH")
        let liveRegion = mgQueryLiveString(forKey: MGKey.regionCode) ?? ""
        let regionLiveOK = !liveRegion.isEmpty && liveRegion != "CH" && liveRegion != "ZA"

        // 2. US RegulatoryModelNumber (97JDvERpVwO+GHtthIh7hA) or Kept Factory Model in LL-Only Mode
        let stagedRegModel = (store.cacheExtra[MGKey.regModelNumber] as? String) ?? ""
        let ogRegModel = (store.originalCacheExtraValue(forKey: MGKey.regModelNumber) as? String) ?? ""
        let usTarget = expectedUSModel
        let regModelReady = isLLOnlyMode
            ? !stagedRegModel.isEmpty
            : ((!stagedRegModel.isEmpty && (stagedRegModel == usTarget || (stagedRegModel.hasPrefix("A") && stagedRegModel != ogRegModel))) || (isNativeNonRestrictedRegion && !stagedRegModel.isEmpty))
        let liveRegModel = mgQueryLiveString(forKey: MGKey.regModelNumber) ?? ""
        let regModelLiveOK = !liveRegModel.isEmpty && (liveRegModel == stagedRegModel || isNativeNonRestrictedRegion)

        // 3. China CacheData Gate (green-tea == 0) & InternalInstall / SiriHub / AdvAI Mutual Exclusion
        let intInstallConflict = store.isEnabled([MGKey.intInstall]) || store.isEnabled([MGKey.intBuild])
        let siriHubConflict = store.isSiriHubConflictActive()
        let advAIConflict = store.isAdvAppleIntellConflictActive()
        var greenTeaCleared = true
        if case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: store.mgCurrentDict) {
            greenTeaCleared = (data[layout.greenTeaOffset] == 0 && data[layout.notGreenTeaOffset] == 1)
        }
        let gateReady = !intInstallConflict && !siriHubConflict && !advAIConflict && greenTeaCleared
        let liveGreenTea = mgQueryLiveBool(forKey: MGCacheDataLayout.greenTeaKey) ?? false
        let liveIntInstall = mgQueryLiveBool(forKey: MGKey.intInstall) ?? false
        let liveSiriHub = mgQueryLiveBool(forKey: MGKey.siriHub) ?? false
        let liveAdvAIConflict = isLiveAdvAIConflictActive()
        let gateLiveOK = !liveGreenTea && !liveIntInstall && !liveSiriHub && !liveAdvAIConflict

        var gateDetail: String
        if intInstallConflict {
            gateDetail = "⚠️ Terdeteksi InternalInstall mode internal aktif (bertentangan dengan AI)"
        } else if siriHubConflict {
            gateDetail = "⚠️ Terdeteksi routing SiriHub aktif (akan memacetkan \"Sedang menambahkan konten dukungan Siri\", dapat diperbaiki sekali klik)"
        } else if advAIConflict {
            gateDetail = "⚠️ Terdeteksi slot eksperimental AI lanjutan aktif (akan menyebabkan error hapus \"kualitas tinggi\" foto, dapat diperbaiki sekali klik)"
        } else if !greenTeaCleared {
            gateDetail = "Slot batasan green-tea versi Tiongkok belum dibuka (disarankan mengaktifkan pembukaan lapisan bawah di bawah)"
        } else {
            gateDetail = "green-tea=false · Tidak ada debug internal, SiriHub, dan konflik hapus"
        }

        // 4. Hardware AI Eligibility & Sub-capabilities
        let nativeAI = isAppleIntellHD()
        let nativeAdvAI = isAdvAppleIntellHD()
        let stagedAI = nativeAI || store.mgKeyBinding(MGKey.appIntellAllKeys).wrappedValue
        let aiReady = stagedAI
        let liveAI = mgQueryLiveBool(forKey: MGKey.appIntell) ?? nativeAI

        let aiDetail: String
        if nativeAdvAI {
            aiDetail = "Perangkat ini (\(originalHardwareProductType())) secara native mendukung semua AI dan kemampuan lanjutan iOS 27"
        } else if nativeAI {
            aiDetail = "Hardware perangkat ini (\(originalHardwareProductType())) secara native mendukung Apple Intelligence (termasuk hapus foto, rekaman panggilan, dan transkripsi)"
        } else {
            aiDetail = stagedAI
                ? "Sakelar AI utama dan sub-kemampuan hapus/tulisan tangan untuk model lama sudah diaktifkan (perlu bersama penyamaran model)"
                : "Sakelar AI untuk model lama belum diaktifkan (perlu diaktifkan dan bersama penyamaran model)"
        }

        return [
            FactorItem(
                id: "region",
                title: isLLOnlyMode ? "1. Penanda Kode Wilayah (Hanya Mode Kompatibel LL)" : "1. Penanda Wilayah Penjualan (LL / LL/A)",
                detail: "Konfigurasi: \(stagedRegCode.isEmpty ? "Belum diatur" : stagedRegCode) / \(stagedSysconfig.isEmpty ? "Belum diatur" : stagedSysconfig) · Real-time perangkat: \(liveRegion.isEmpty ? "Tidak diketahui" : liveRegion)",
                isReady: regionReady,
                isLiveActive: regionLiveOK
            ),
            FactorItem(
                id: "regmodel",
                title: isLLOnlyMode ? "2. Model Regulasi (Pertahankan Pabrik \(stagedRegModel.isEmpty ? "Default" : stagedRegModel))" : "2. Model Regulasi Versi AS (\(usTarget))",
                detail: "Konfigurasi: \(stagedRegModel.isEmpty ? "Belum diatur" : stagedRegModel) · Real-time perangkat: \(liveRegModel.isEmpty ? "Tidak diketahui" : liveRegModel)",
                isReady: regModelReady,
                isLiveActive: regModelLiveOK
            ),
            FactorItem(
                id: "gate",
                title: "3. Pemeriksaan Gerbang Versi Tiongkok dan Kunci Mutual Exclusion",
                detail: gateDetail,
                isReady: gateReady,
                isLiveActive: gateLiveOK
            ),
            FactorItem(
                id: "ai",
                title: "4. Akses AI On-Device dan Sub-Kemampuan",
                detail: aiDetail,
                isReady: aiReady,
                isLiveActive: liveAI
            )
        ]
    }

    var body: some View {
        let items = factors
        let readyCount = items.filter(\.isReady).count
        let allReady = (readyCount == items.count)
        let allLive = items.allSatisfy(\.isLiveActive)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: allReady ? "sparkles" : "wand.and.stars")
                    .foregroundStyle(allReady ? Color.green : Color.orange)
                    .font(.subheadline.weight(.semibold))
                Text("Pemeriksaan 4 Faktor Aktivasi Apple Intelligence")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(allLive ? "Perangkat sudah aktif" : (allReady ? "Lengkap · Menunggu terapkan dan restart" : "Lengkap \(readyCount)/\(items.count)"))
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(allLive ? Color.green.opacity(0.18) : (allReady ? Color.blue.opacity(0.18) : Color.orange.opacity(0.18)))
                    )
                    .foregroundStyle(allLive ? Color.green : (allReady ? Color.blue : Color.orange))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: item.isReady ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(item.isReady ? Color.green : Color.orange)
                            .font(.caption)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 10) {
                if !allReady {
                    Button {
                        Haptic.shared.play(.soft)
                        store.applyAppleIntelligenceOneClickFix()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                            Text("Lengkapi / Perbaiki Sekali Klik")
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasWriteAccess && !weOnADebugBuild)
                }

                Button {
                    onOpenInspector()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg.rectangle")
                        Text("Probe Verifikasi Perangkat Asli")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemFill), in: Capsule())
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Button {
                    Alertinator.shared.alert(title: "Panduan Koeksistensi Penanya Panggilan Mandarin (Fitur Uji)", body: MGMsg.callScreeningGuide)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.badge.waveform.fill")
                        Text("Panduan Koeksistensi Penanya Panggilan [Uji]")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Feature 1: Read-Only Live MGCopyAnswer Verifier & Dynamic Slot Inspector

struct MGInspectorView: View {
    @ObservedObject var store: GestaltStore
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var filterModifiedOnly = false
    @State private var customProbeKey = ""
    @State private var customProbeResult: String? = nil
    @State private var selectedSlotLiveCache: [String: String] = [:]
    @State private var refreshToken = UUID()

    private struct CuratedProbeItem: Identifiable {
        var id: String { key }
        let title: String
        let key: String
        let category: String
    }

    private let curatedItems: [CuratedProbeItem] = [
        // Region & Regulatory
        CuratedProbeItem(title: "Kode Wilayah Penjualan (RegionCode)", key: MGKey.regionCode, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Wilayah Penjualan Sistem (RegionInfoFromSysconfig)", key: MGKey.regionSysconfig, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Model Regulasi (RegulatoryModelNumber)", key: MGKey.regModelNumber, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Penanda Hardware Model (ProductType)", key: MGKey.prodType, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Penanda Batasan Versi Tiongkok (green-tea)", key: MGCacheDataLayout.greenTeaKey, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Penanda Perangkat Non-Tiongkok (not-green-tea)", key: MGCacheDataLayout.notGreenTeaKey, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        CuratedProbeItem(title: "Penanda Tampilan WLAN (wapi)", key: MGCacheDataLayout.wapiKey, category: "Unlock Versi Tiongkok dan Akses Wilayah"),
        // Apple Intelligence & iOS 27 AI
        CuratedProbeItem(title: "Sakelar Utama Apple Intelligence (GenerativeModelSystems)", key: MGKey.appIntell, category: "Apple Intelligence dan iOS 27 AI"),
        CuratedProbeItem(title: "Fitur \"Hapus\" Foto (Photos Clean Up)", key: MGKey.photosCleanUp, category: "Apple Intelligence dan iOS 27 AI"),
        CuratedProbeItem(title: "Sintesis Tulisan Tangan Catatan (Handwriting Synthesis)", key: MGKey.handwritingSynth, category: "Apple Intelligence dan iOS 27 AI"),
        CuratedProbeItem(title: "Terjemahan Real-time Pribadi (Personal Translator)", key: MGKey.personalTranslator, category: "Apple Intelligence dan iOS 27 AI"),
        CuratedProbeItem(title: "Audio Intelligence iOS 27 (Audio Intelligence)", key: MGKey.audioIntell, category: "Apple Intelligence dan iOS 27 AI"),
        // Media, Camera & Health
        CuratedProbeItem(title: "Audio Mix Galeri dan Kamera", key: MGKey.audioMix, category: "Kemampuan Lanjutan Imaging dan Kesehatan"),
        CuratedProbeItem(title: "Perekaman Audio Spasial (spatial-audio-recording)", key: MGKey.spatialAudioRec, category: "Kemampuan Lanjutan Imaging dan Kesehatan"),
        CuratedProbeItem(title: "Audio Spasial FaceTime (spatial-facetime-audio)", key: MGKey.spatialFaceTimeAudio, category: "Kemampuan Lanjutan Imaging dan Kesehatan"),
        CuratedProbeItem(title: "Jepretan Seketika Saat Rana Ditekan (ResponsiveShutter)", key: MGKey.responsiveShutter, category: "Kemampuan Lanjutan Imaging dan Kesehatan"),
        CuratedProbeItem(title: "Evaluasi Tren Hipertensi Kesehatan (HypertensionNotifications)", key: MGKey.hypertensionNotif, category: "Kemampuan Lanjutan Imaging dan Kesehatan"),
        // Display & System
        CuratedProbeItem(title: "Render Liquid Glass Hemat Daya", key: MGKey.liquidGlassLowPower, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Fitur Dynamic Island", key: MGKey.island, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Always-On Display (AOD)", key: MGKey.AOD, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Batas Pengisian 80% (80ChargeLimit)", key: MGKey.chargeLim, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Suara Boot/Shutdown (BootChime)", key: MGKey.bootChime, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Tombol Aksi (ActionButton)", key: MGKey.actButton, category: "Tampilan dan Fitur Hardware"),
        CuratedProbeItem(title: "Mode Instalasi Internal Apple (InternalInstall)", key: MGKey.intInstall, category: "Tampilan dan Fitur Hardware"),
        // [Fitur Uji] Experimental Slots
        CuratedProbeItem(title: "[Uji] Pengecualian Suara Rana Kamera Regional", key: MGKey.shutterRelaxation, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Mikrofon Ganda High-Low Power Bersamaan", key: MGKey.concurrentHPLPMics, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Redraw Cahaya Lokal Galeri", key: MGKey.photosLocalLight, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Penangkapan Spasial Ultra-Wide", key: MGKey.spatialOverCapture, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Penangkapan Audio Video Stereo", key: MGKey.stereoAudioRec, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Tampilkan Siklus Baterai dan Tanggal Model Lama", key: MGKey.legacyBatteryInfo, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] AOD Kecerahan Tinggi Outdoor", key: MGKey.highLuminanceAOD, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] CarPlay Ultra Multi-Layar Otomotif", key: MGKey.carPlay2, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Pengiriman Sampling Touch 120Hz", key: MGKey.touchDelivery120Hz, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Ekualisasi Audio Alat Bantu Dengar Klinis", key: MGKey.hearingAidEQ, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Deteksi Risiko Sleep Apnea", key: MGKey.breathingDisturbances, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Sakelar Batasan Software SpO2 Versi AS", key: MGKey.usBloodOxygen, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Mode Olahraga Ekstrem Outdoor", key: MGKey.workoutUltra, category: "Fitur Uji (Eksperimen CacheData)"),
        CuratedProbeItem(title: "[Uji] Routing Intent Siri Hub On-Device", key: MGKey.siriHub, category: "Fitur Uji (Eksperimen CacheData)")
    ]

    var body: some View {
        List {
            Section {
                Picker("Mode Tampilan", selection: $selectedTab) {
                    Text("Verifikasi Inti").tag(0)
                    Text("Tabel Slot Lengkap").tag(1)
                    Text("Probe Bebas").tag(2)
                }
                .pickerStyle(.segmented)
            }

            if selectedTab == 0 {
                curatedVerificationSections
            } else if selectedTab == 1 {
                allSlotsSections
            } else {
                customProbeSections
            }
        }
        .id(refreshToken)
        .searchable(text: $searchText, prompt: "Cari nama kunci, nomor slot, atau nama fitur")
        .navigationTitle("Verifikasi Perangkat Asli dan Probe Slot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedSlotLiveCache.removeAll()
                    refreshToken = UUID()
                    Haptic.shared.play(.soft)
                } label: {
                    Label("Segarkan Status Real-time", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Tab 0: Curated Live Verification

    @ViewBuilder
    private var curatedVerificationSections: some View {
        let layoutResult = MGCacheDataCoordinator.shared.resolveValidated(for: store.mgCurrentDict)
        let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL)

        if case .success((let layout, _)) = layoutResult {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("Citra real-time libMobileGestalt.dylib perangkat")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(layout.slotCount) slot · \(layout.byteCount) B")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text("CacheUUID: \(layout.uuid)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }

        let categories = ["Unlock Versi Tiongkok dan Akses Wilayah", "Apple Intelligence dan iOS 27 AI", "Kemampuan Lanjutan Imaging dan Kesehatan", "Tampilan dan Fitur Hardware"]
        ForEach(categories, id: \.self) { cat in
            let filtered = curatedItems.filter { item in
                guard item.category == cat else { return false }
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                let q = searchText.lowercased()
                return item.title.lowercased().contains(q) || item.key.lowercased().contains(q)
            }
            if !filtered.isEmpty {
                Section {
                    ForEach(filtered) { item in
                        curatedRow(for: item, layoutResult: layoutResult, ogDict: ogDict)
                    }
                } header: {
                    Text(cat)
                }
            }
        }
    }

    @ViewBuilder
    private func curatedRow(
        for item: CuratedProbeItem,
        layoutResult: Result<(MGCacheDataLayout, Data), MGCacheResolutionError>,
        ogDict: NSDictionary?
    ) -> some View {
        let info = evaluateKeyState(key: item.key, layoutResult: layoutResult, ogDict: ogDict)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(info.badgeText)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(info.badgeColor.opacity(0.16)))
                    .foregroundStyle(info.badgeColor)
            }

            HStack(spacing: 6) {
                Text(item.key)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let slotBadge = info.slotLocationText {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(slotBadge)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                }
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cadangan Pabrik")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(info.originalText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Divider().frame(height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Konfigurasi Saat Ini")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(info.stagedText)
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                        .foregroundStyle(.primary)
                }
                Divider().frame(height: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nilai MGCopyAnswer Perangkat Asli")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(info.liveText)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(info.badgeColor)
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 3)
    }

    private struct KeyEvaluation {
        let slotLocationText: String?
        let originalText: String
        let stagedText: String
        let liveText: String
        let badgeText: String
        let badgeColor: Color
    }

    private func evaluateKeyState(
        key: String,
        layoutResult: Result<(MGCacheDataLayout, Data), MGCacheResolutionError>,
        ogDict: NSDictionary?
    ) -> KeyEvaluation {
        let liveText = mgQueryLiveFormatted(forKey: key)
        let ogExtra = ogDict?["CacheExtra"] as? NSDictionary
        let ogData = ogDict?["CacheData"] as? Data

        var slotLoc: String? = nil
        var origValText = "Belum diatur"
        var stagedValText = "Belum diatur"

        if case .success((let layout, let curData)) = layoutResult,
           let slotIdx = layout.slotIndex(forKey: key),
           layout.validateSingleBooleanSlot(slotIdx, in: curData) {
            let off = slotIdx * 8
            slotLoc = String(format: "Slot CacheData #%d (0x%X)", slotIdx, off)
            let curBit = curData[off] == 1
            stagedValText = curBit ? "true (0x01)" : "false (0x00)"

            if let ogData, ogData.count == layout.byteCount, layout.validateSingleBooleanSlot(slotIdx, in: ogData) {
                let ogBit = ogData[off] == 1
                origValText = ogBit ? "true (0x01)" : "false (0x00)"
            } else if let recorded = MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: ogDict) {
                origValText = recorded ? "true (0x01)" : "false (0x00)"
            }
        } else {
            slotLoc = "Kunci Dictionary CacheExtra"
            if let ogVal = ogExtra?[key] {
                origValText = mgFormatValue(ogVal)
            }
            if let curVal = store.cacheExtra[key] {
                stagedValText = mgFormatValue(curVal)
            }
        }

        let liveNorm = normalizeComparison(liveText)
        let stagedNorm = normalizeComparison(stagedValText)
        let origNorm = normalizeComparison(origValText)

        let badgeText: String
        let badgeColor: Color
        if stagedNorm != origNorm && stagedValText != "Belum diatur" {
            if liveNorm == stagedNorm {
                badgeText = "✅ Diubah dan aktif di perangkat"
                badgeColor = .green
            } else {
                badgeText = "⏳ Menunggu terapkan dan restart"
                badgeColor = .orange
            }
        } else if liveNorm == "true" {
            badgeText = "Native perangkat aktif"
            badgeColor = .blue
        } else {
            badgeText = "Default pabrik"
            badgeColor = .secondary
        }

        return KeyEvaluation(
            slotLocationText: slotLoc,
            originalText: origValText,
            stagedText: stagedValText,
            liveText: liveText,
            badgeText: badgeText,
            badgeColor: badgeColor
        )
    }

    private func normalizeComparison(_ text: String) -> String {
        if text.hasPrefix("true") || text == "1 (Int)" || text == "1" { return "true" }
        if text.hasPrefix("false") || text == "0 (Int)" || text == "0" || text.hasPrefix("nil") { return "false" }
        return text
    }

    // MARK: - Tab 1: Full Dynamic Slot Table (0..<slotCount)

    @ViewBuilder
    private var allSlotsSections: some View {
        let layoutResult = MGCacheDataCoordinator.shared.resolveValidated(for: store.mgCurrentDict)
        switch layoutResult {
        case .failure(let err):
            Section {
                Text("Lingkungan saat ini tidak dapat mengurai tabel slot dinamis: \(err.localizedDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .success((let layout, let curData)):
            let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL)
            let ogData = (ogDict?["CacheData"] as? Data)
            let descriptors = MGCacheDataCoordinator.shared.allDescriptors()
            let descBySlot: [Int: [MGSlotDescriptorInfo]] = Dictionary(grouping: descriptors.filter { $0.slotIndex >= 0 }, by: \.slotIndex)

            Section {
                Toggle("Hanya tampilkan slot yang berbeda dari cadangan pabrik", isOn: $filterModifiedOnly)
            }

            let matchingSlots = (0..<layout.slotCount).filter { slotIdx in
                let off = slotIdx * 8
                if filterModifiedOnly {
                    guard let ogData, ogData.count == curData.count else { return false }
                    let sliceA = curData[off..<(off + 8)]
                    let sliceB = ogData[off..<(off + 8)]
                    let validA = curData[layout.validityOffset(for: slotIdx)]
                    let validB = ogData[layout.validityOffset(for: slotIdx)]
                    if sliceA == sliceB && validA == validB { return false }
                }
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !q.isEmpty else { return true }
                if "\(slotIdx)".contains(q) || String(format: "0x%x", off).contains(q) {
                    return true
                }
                if let list = descBySlot[slotIdx] {
                    return list.contains { d in
                        d.obfuscatedKey.lowercased().contains(q) ||
                        mgKeyDisplayName(d.obfuscatedKey).lowercased().contains(q)
                    }
                }
                return false
            }

            Section {
                ForEach(matchingSlots, id: \.self) { slotIdx in
                    slotRow(
                        slotIdx: slotIdx,
                        layout: layout,
                        curData: curData,
                        ogData: ogData,
                        descriptors: descBySlot[slotIdx] ?? []
                    )
                }
            } header: {
                Text("Resolusi dinamis total \(matchingSlots.count) / \(layout.slotCount) slot (ketuk baris untuk memanggil MGCopyAnswer secara real-time)")
            }
        }
    }

    @ViewBuilder
    private func slotRow(
        slotIdx: Int,
        layout: MGCacheDataLayout,
        curData: Data,
        ogData: Data?,
        descriptors: [MGSlotDescriptorInfo]
    ) -> some View {
        let valOff = slotIdx * 8
        let validOff = layout.validityOffset(for: slotIdx)
        let isValid = curData[validOff] == 1
        let firstByte = curData[valOff]
        let isChanged: Bool = {
            guard let ogData, ogData.count == curData.count else { return false }
            return curData[valOff..<(valOff + 8)] != ogData[valOff..<(valOff + 8)] || curData[validOff] != ogData[validOff]
        }()
        let primaryDesc = descriptors.first
        let keyStr = primaryDesc?.obfuscatedKey ?? "(Slot kosong yang dipertahankan / deskriptor tidak terikat)"
        let displayTitle = primaryDesc.map { mgKeyDisplayName($0.obfuscatedKey) } ?? "Slot dipertahankan #\(slotIdx)"

        Button {
            if let key = primaryDesc?.obfuscatedKey {
                selectedSlotLiveCache[key] = mgQueryLiveFormatted(forKey: key)
                Haptic.shared.play(.soft)
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(String(format: "Slot #%d (0x%04X)", slotIdx, valOff))
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(isChanged ? Color.orange : Color.accentColor)
                    if let qType = primaryDesc?.queryType {
                        Text(qType == 11 ? "Bool (qtype=11)" : "qtype=\(qType)")
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(isValid ? (firstByte == 1 ? "0x01 (Valid)" : String(format: "0x%02X (Valid)", firstByte)) : "Invalid (0x00)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(isValid ? (firstByte == 1 ? Color.green : Color.primary) : Color.secondary)
                }

                if displayTitle != keyStr {
                    Text(displayTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }

                Text(keyStr)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let key = primaryDesc?.obfuscatedKey, let liveVal = selectedSlotLiveCache[key] {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("Kembalian MGCopyAnswer real-time: \(liveVal)")
                            .font(.system(.caption2, design: .monospaced).weight(.semibold))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab 2: Free-Form Key Probe

    @ViewBuilder
    private var customProbeSections: some View {
        Section {
            TextField("Masukkan kunci terobfuskasi 22 karakter atau kunci plaintext (mis. RegionCode / ProductType)", text: $customProbeKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                let trimmed = customProbeKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let live = mgQueryLiveFormatted(forKey: trimmed)
                var lines: [String] = [
                    "Nama kunci yang dikueri: \(trimmed)",
                    "Nilai kembalian real-time MGCopyAnswer: \(live)"
                ]
                if let extraVal = store.cacheExtra[trimmed] {
                    lines.append("Nilai CacheExtra saat ini: \(mgFormatValue(extraVal))")
                } else {
                    lines.append("Nilai CacheExtra saat ini: (tidak ada)")
                }
                if let ogVal = store.originalCacheExtraValue(forKey: trimmed) {
                    lines.append("Cadangan CacheExtra pabrik: \(mgFormatValue(ogVal))")
                }
                let allDescs = MGCacheDataCoordinator.shared.allDescriptors()
                if let desc = allDescs.first(where: { $0.obfuscatedKey == trimmed }) {
                    lines.append("Deskriptor pustaka sistem: slot = \(desc.slotIndex), queryType = \(desc.queryType)")
                    if desc.slotIndex >= 0,
                       case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: store.mgCurrentDict),
                       desc.slotIndex < layout.slotCount {
                        let vOff = desc.slotIndex * 8
                        let valOff = layout.validityOffset(for: desc.slotIndex)
                        lines.append(String(format: "Offset CacheData: 0x%X (nilai=0x%02X), offset bit valid: 0x%X (validity=%d)",
                                            vOff, data[vOff], valOff, data[valOff]))
                    }
                }
                customProbeResult = lines.joined(separator: "\n")
                Haptic.shared.play(.soft)
            } label: {
                Label("Jalankan Probe Read-Only Sekarang", systemImage: "magnifyingglass")
            }
        } header: {
            Text("Probe Real-time Nama Kunci Bebas (Read-Only Murni · Tanpa Penulisan)")
        } footer: {
            Text("Mendukung input langsung kunci terobfuskasi Base64 (mis. aVL5GE3tx0LSCI/ErfrJGA) atau nama kunci plaintext standar yang didukung sistem (mis. ProductType, RegionCode, BuildVersion), membandingkan secara real-time nilai kembalian MGCopyAnswer dalam proses dengan status cache disk.")
        }

        if let customProbeResult {
            Section {
                Text(customProbeResult)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
            } header: {
                Text("Hasil Probe")
            }
        }
    }
}
