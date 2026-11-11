//
//  mg.swift
//  mond
//
//  Created by ruter on 16.07.26.
//

import Foundation
import CoreFoundation
import CryptoKit
import Darwin
import MachO
import UIKit

struct MGDiffItem: Identifiable {
    let id: String
    let label: String
    let keyPath: String
    let beforeText: String
    let afterText: String
}

func mgValidatePlistData(_ data: Data) -> (Bool, String) {
    guard data.count > 256 else {
        return (false, "Data MobileGestalt yang akan ditulis terlalu kecil (\(data.count) byte), penulisan diblokir.")
    }
    guard let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
          let dict = obj as? NSDictionary else {
        return (false, "Data yang akan ditulis bukan dictionary Plist yang valid, penulisan diblokir.")
    }
    guard let cacheExtra = dict["CacheExtra"] as? NSDictionary, cacheExtra.count > 0 else {
        return (false, "Plist yang akan ditulis tidak memiliki dictionary CacheExtra yang valid, penulisan diblokir.")
    }
    guard let cacheData = dict["CacheData"] as? Data, !cacheData.isEmpty else {
        return (false, "Plist yang akan ditulis tidak memiliki segmen biner CacheData yang valid, penulisan diblokir.")
    }
    return (true, "ok")
}

func mgPlistValuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
    switch (lhs, rhs) {
    case (nil, nil):
        return true
    case (nil, _), (_, nil):
        return false
    case (let a?, let b?):
        if let numA = a as? NSNumber, let numB = b as? NSNumber {
            let isBoolA = CFGetTypeID(numA) == CFBooleanGetTypeID()
            let isBoolB = CFGetTypeID(numB) == CFBooleanGetTypeID()
            if isBoolA != isBoolB { return false }
            if isBoolA { return numA.boolValue == numB.boolValue }
            let isFloatA = CFNumberIsFloatType(numA)
            let isFloatB = CFNumberIsFloatType(numB)
            if isFloatA != isFloatB { return false }
            return isFloatA ? (numA.doubleValue == numB.doubleValue) : (numA.stringValue == numB.stringValue)
        }
        if let strA = a as? String, let strB = b as? String { return strA == strB }
        if let dataA = a as? Data, let dataB = b as? Data { return dataA == dataB }
        if let dateA = a as? Date, let dateB = b as? Date { return dateA == dateB }
        if let arrA = a as? NSArray, let arrB = b as? NSArray {
            guard arrA.count == arrB.count else { return false }
            for idx in 0..<arrA.count where !mgPlistValuesEqual(arrA[idx], arrB[idx]) {
                return false
            }
            return true
        }
        if let dictA = a as? NSDictionary, let dictB = b as? NSDictionary {
            guard dictA.count == dictB.count else { return false }
            for (k, valA) in dictA {
                guard let keyStr = k as? String else { return dictA.isEqual(to: dictB as? [AnyHashable: Any] ?? [:]) }
                if !mgPlistValuesEqual(valA, dictB[keyStr]) { return false }
            }
            return true
        }
        return (a as AnyObject).isEqual(b)
    }
}

func mgFormatValue(_ val: Any?) -> String {
    guard let val else { return "(tidak ada / telah dihapus)" }
    if let num = val as? NSNumber {
        if CFGetTypeID(num) == CFBooleanGetTypeID() {
            return num.boolValue ? "true (Bool)" : "false (Bool)"
        }
        if CFNumberIsFloatType(num) {
            return "\(num.doubleValue) (Float)"
        }
        return num.stringValue
    }
    if let str = val as? String { return str.isEmpty ? "\"\"" : str }
    if let data = val as? Data { return "<Data: \(data.count) byte>" }
    if let arr = val as? NSArray {
        let items = arr.map { mgFormatValue($0) }.joined(separator: ", ")
        return "[\(items)]"
    }
    if let dict = val as? NSDictionary { return "<Dict: \(dict.count) item>" }
    return String(describing: val)
}

func mgKeyDisplayName(_ key: String) -> String {
    let names: [String: String] = [
        MGKey.regionCode: "Kode Wilayah (RegionCode)",
        MGKey.regionInfo: "Wilayah Penjualan (RegionInfo)",
        MGKey.regionSysconfig: "Wilayah Penjualan Sistem (RegionInfoFromSysconfig)",
        MGKey.regModelNumber: "Model Regulasi (RegulatoryModelNumber)",
        MGKey.appIntell: "Sakelar Utama Apple Intelligence",
        MGKey.photosCleanUp: "Fitur \"Hapus\" Foto (Photos Clean Up)",
        MGKey.handwritingSynth: "Sintesis Tulisan Tangan Catatan (Handwriting Synthesis)",
        MGKey.audioIntell: "Kecerdasan Audio iOS 27 (Audio Intelligence)",
        MGKey.personalTranslator: "Terjemahan Real-time Pribadi (Personal Translator)",
        MGKey.audioMix: "Audio Mix Foto dan Kamera (Audio Mix)",
        MGKey.spatialAudioRec: "Perekaman Audio Spasial (spatial-audio-recording)",
        MGKey.spatialFaceTimeAudio: "Audio Spasial FaceTime (spatial-facetime-audio)",
        MGKey.responsiveShutter: "Jepretan Seketika Saat Tombol Rana Ditekan (ResponsiveShutter)",
        MGKey.hypertensionNotif: "Evaluasi Tren Hipertensi Kesehatan (HypertensionNotifications)",
        MGCacheDataLayout.greenTeaKey: "Penanda Batasan Versi Tiongkok (green-tea)",
        MGCacheDataLayout.notGreenTeaKey: "Penanda Perangkat Non-Tiongkok (not-green-tea)",
        MGCacheDataLayout.wapiKey: "Penanda Tampilan WLAN (wapi)",
        MGKey.liquidGlassLowPower: "Render Liquid Glass Hemat Daya",
        MGKey.island: "Fitur Dynamic Island",
        MGKey.AOD: "Always-On Display (AOD)",
        MGKey.AOTime: "Waktu Always-On Display",
        MGKey.AODVibrancy: "Saturasi AOD",
        MGKey.chargeLim: "Batas Pengisian 80%",
        MGKey.bootChime: "Suara Boot/Shutdown",
        MGKey.intInstall: "Mode Instalasi Internal Apple",
        MGKey.intBuild: "Penanda Build Internal",
        MGKey.srd: "Perangkat Riset Keamanan (SRD)",
        MGKey.prodType: "Pengenal Tipe Perangkat (ProductType)",
        MGKey.modelNameOuter1: "Nama Produk Perangkat",
        MGKey.modelNameOuter2: "Nama Pemasaran Perangkat",
        MGKey.crashDet: "Deteksi Kecelakaan",
        MGKey.pwm: "Sakelar Dimming PWM",
        MGKey.appPencil: "Dukungan Apple Pencil",
        MGKey.camButton: "Tombol Kontrol Kamera",
        MGKey.grapPefr: "Tingkat Performa Grafis",
        MGKey.actButton: "Tombol Aksi",
        MGKey.tapToWake: "Ketuk untuk Bangunkan",
        MGKey.stageMgr: "Stage Manager",
        MGKey.shutterRelaxation: "[Uji] Pengecualian Suara Rana Kamera Regional",
        MGKey.shutterKeyboardMutePreserve: "[Uji] Pertahankan Suara Rana Wajib Saat Keyboard Senyap",
        MGKey.shutterLegacyMutePreserve: "[Uji] Pertahankan Suara Rana Wajib untuk Model Lama",
        MGKey.concurrentHPLPMics: "[Uji] Perekaman Mikrofon Ganda High/Low Power Bersamaan",
        MGKey.photosLocalLight: "[Uji] Redraw Efek Cahaya Lokal Foto",
        MGKey.toneMapping: "[Uji] Pemetaan Nada Dinamis",
        MGKey.hdrDeferredProcessing: "[Uji] Render Delay HDR Depth",
        MGKey.spatialOverCapture: "[Uji] Penangkapan Spasial Ultra-Wide",
        MGKey.stereoAudioRec: "[Uji] Perekaman Audio Stereo Video",
        MGKey.p3VideoRec: "[Uji] Perekaman Video Wide Color P3",
        MGKey.touchSensitiveCamControl: "[Uji] Kontrol Kamera Sensitif Sentuh Kapasitif",
        MGKey.hardwareDetents: "[Uji] Damping Taktil Detent Fisik",
        MGKey.cameraHaptics: "[Uji] Umpan Balik Haptik Halus Kamera",
        MGKey.legacyBatteryInfo: "[Uji] Tampilan Siklus Baterai dan Tanggal Model Lama",
        MGKey.legacyDynamicEndOfCharge: "[Uji] Pemutusan Pengisian Cerdas Model Lama",
        MGKey.highLuminanceAOD: "[Uji] AOD Kecerahan Tinggi Outdoor",
        MGKey.aodFlipbook: "[Uji] Frame Buffer AOD Low-Power Flipbook",
        MGKey.carPlay2: "[Uji] CarPlay Ultra Generasi Baru",
        MGKey.touchDelivery120Hz: "[Uji] Pengiriman Sample Touch 120Hz",
        MGKey.hearingAidEQ: "[Uji] Equalizer Audio Alat Bantu Dengar Klinis",
        MGKey.hearingAidLE: "[Uji] Audio Low-Power Alat Bantu Dengar",
        MGKey.hearingAidPowerRed: "[Uji] Mode Pengurangan Daya Alat Bantu Dengar",
        MGKey.breathingDisturbances: "[Uji] Deteksi Risiko Sleep Apnea",
        MGKey.usBloodOxygen: "[Uji] Sakelar Batasan Software SpO2 Versi AS",
        MGKey.workoutUltra: "[Uji] Mode Olahraga Ekstrem Outdoor",
        MGKey.timeInDaylight: "[Uji] Pemantauan Durasi Paparan Sinar Matahari",
        MGKey.siriHub: "[Uji] Routing Intent Siri Hub On-Device",
        MGKey.onDeviceSiri: "[Uji] Kemampuan Siri On-Device Offline",
        MGKey.modelPruning: "[Uji] Dynamic Pruning Model Perintah On-Device",
        "uKc7FPnEO++lVhHWHFlGbQ": "Mode Perangkat iPad",
        "mG0AnH/Vy1veoqoLRAIgTA": "Aplikasi Floating Multitasking",
        "UCG5MkVahJxG1YULbbd5Bg": "Slide Over Multitasking",
        "ZYqko/XM5zD3XBfN5RmaXA": "Split View Multitasking Tetap",
        "nVh/gwNpy7Jv1NOk00CMrw": "Picture in Picture Multitasking",
        "ArtworkDeviceSubType": "Subtipe Layar (Subtype)",
        "ArtworkDeviceProductDescription": "Nama Model Kustom"
    ]
    return names[key] ?? key
}

func mgComputeDiff(from beforeDict: NSDictionary, to afterDict: NSDictionary) -> [MGDiffItem] {
    var items: [MGDiffItem] = []

    let beforeCacheData = beforeDict["CacheData"] as? Data
    let afterCacheData = afterDict["CacheData"] as? Data
    if beforeCacheData != afterCacheData {
        let slotDiffs = MGCacheDataCoordinator.shared.diffDetails(from: beforeDict, to: afterDict)
        if !slotDiffs.isEmpty {
            for d in slotDiffs {
                items.append(MGDiffItem(
                    id: d.id,
                    label: d.label,
                    keyPath: d.keyPath,
                    beforeText: d.beforeText,
                    afterText: d.afterText
                ))
            }
        } else {
            items.append(MGDiffItem(
                id: "root.CacheData",
                label: "Cache Biner Tingkat Rendah (CacheData)",
                keyPath: "CacheData",
                beforeText: mgFormatValue(beforeCacheData),
                afterText: mgFormatValue(afterCacheData)
            ))
        }
    }

    let beforeExtra = beforeDict["CacheExtra"] as? NSDictionary ?? [:]
    let afterExtra = afterDict["CacheExtra"] as? NSDictionary ?? [:]
    var allKeys = Set<String>()
    for k in beforeExtra.allKeys { if let s = k as? String { allKeys.insert(s) } }
    for k in afterExtra.allKeys { if let s = k as? String { allKeys.insert(s) } }

    for key in allKeys.sorted() {
        let oldVal = beforeExtra[key]
        let newVal = afterExtra[key]
        if mgPlistValuesEqual(oldVal, newVal) { continue }

        if key == MGKey.artwork,
           let oldArt = oldVal as? NSDictionary,
           let newArt = newVal as? NSDictionary {
            var artKeys = Set<String>()
            for k in oldArt.allKeys { if let s = k as? String { artKeys.insert(s) } }
            for k in newArt.allKeys { if let s = k as? String { artKeys.insert(s) } }
            for aKey in artKeys.sorted() {
                if !mgPlistValuesEqual(oldArt[aKey], newArt[aKey]) {
                    items.append(MGDiffItem(
                        id: "Artwork.\(aKey)",
                        label: mgKeyDisplayName(aKey),
                        keyPath: "\(MGKey.artwork) → \(aKey)",
                        beforeText: mgFormatValue(oldArt[aKey]),
                        afterText: mgFormatValue(newArt[aKey])
                    ))
                }
            }
            continue
        }

        items.append(MGDiffItem(
            id: "CacheExtra.\(key)",
            label: mgKeyDisplayName(key),
            keyPath: key,
            beforeText: mgFormatValue(oldVal),
            afterText: mgFormatValue(newVal)
        ))
    }

    return items
}

func mgExcludeFromCloudBackup(_ url: URL) {
    var target = url
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? target.setResourceValues(values)
}

func mgComputeSHA256Hex(_ data: Data) -> String {
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

enum MGFactoryRestoreOutcome {
    case restoredSuccessfully(details: String)
    case blockedNeedsCleanRebuild(title: String, reason: String)
    case failed(reason: String)
}

func mgSyncSystemVaultBackup(_ data: Data, hexDigest: String) {
    let vaultDir = MGURL.systemVaultGestaltURL.deletingLastPathComponent()
    if !FileManager.default.isWritableFile(atPath: vaultDir.path) {
        _ = wq.grantAccess(path: vaultDir.path)
    }
    guard FileManager.default.isWritableFile(atPath: vaultDir.path) else { return }
    do {
        try data.write(to: MGURL.systemVaultGestaltURL, options: .atomic)
        mgExcludeFromCloudBackup(MGURL.systemVaultGestaltURL)
        try Data(hexDigest.utf8).write(to: MGURL.systemVaultSHA256URL, options: .atomic)
        mgExcludeFromCloudBackup(MGURL.systemVaultSHA256URL)
    } catch {
        print("(mg-vault) sinkronisasi vault sistem gagal: \(error.localizedDescription)")
    }
}

func mgSaveOriginalBackupWithDigest(_ data: Data) throws {
    let hex = mgComputeSHA256Hex(data)
    try data.write(to: MGURL.savedGestaltURL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.savedGestaltURL)
    try Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
    mgSyncSystemVaultBackup(data, hexDigest: hex)
}

func mgVerifyBackupFileIntegrity(plistURL: URL, sha256URL: URL, requireDigestFile: Bool = false) -> (Bool, String) {
    guard let data = try? Data(contentsOf: plistURL), !data.isEmpty else {
        return (false, "Tidak dapat menemukan atau membaca file cadangan \(plistURL.lastPathComponent)!")
    }
    let check = mgValidatePlistData(data)
    guard check.0 else {
        return (false, "Struktur file cadangan telah rusak: \(check.1)")
    }
    if FileManager.default.fileExists(atPath: sha256URL.path),
       let savedHexData = try? Data(contentsOf: sha256URL),
       let savedHex = String(data: savedHexData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
       savedHex.count == 64 {
        let actualHex = mgComputeSHA256Hex(data)
        if actualHex.caseInsensitiveCompare(savedHex) != .orderedSame {
            return (false, "Verifikasi ringkasan integritas SHA-256 file cadangan gagal (diharapkan \(savedHex.prefix(12))..., aktual \(actualHex.prefix(12))...), mungkin telah dimanipulasi atau rusak!")
        }
    } else if requireDigestFile {
        return (false, "File verifikasi integritas SHA-256 yang sesuai tidak ditemukan!")
    }
    return (true, "ok")
}

func mgVerifyOriginalBackupIntegrity() -> (Bool, String) {
    return mgVerifyBackupFileIntegrity(plistURL: MGURL.savedGestaltURL, sha256URL: MGURL.savedGestaltSHA256URL)
}

func mgHasSyncedSystemVault() -> Bool {
    return mgVerifyBackupFileIntegrity(
        plistURL: MGURL.systemVaultGestaltURL,
        sha256URL: MGURL.systemVaultSHA256URL,
        requireDigestFile: true
    ).0
}

func mgDetectSuspectedThirdPartyModification(in dict: NSDictionary) -> String? {
    let extra = dict["CacheExtra"] as? NSDictionary ?? [:]
    let kernelMachine = machineName()
    if let plistProd = extra[MGKey.prodType] as? String,
       !plistProd.isEmpty,
       !kernelMachine.isEmpty,
       plistProd != kernelMachine {
        return "Terdeteksi pengenal tipe perangkat (\(plistProd)) tidak cocok dengan model hardware kernel asli (\(kernelMachine)) (mungkin sebelumnya pernah mengaktifkan penyamaran model)"
    }
    if (extra[MGKey.intInstall] as? NSNumber)?.intValue == 1 || (extra[MGKey.intBuild] as? NSNumber)?.intValue == 1 {
        return "Terdeteksi Mode Instalasi Internal (InternalInstall / InternalBuild) dalam keadaan aktif (menunjukkan perangkat pernah dimodifikasi oleh alat lain sebelum aplikasi ini dipasang, bertentangan dengan Apple Intelligence; sekarang Anda dapat langsung menonaktifkan sakelar yang sesuai untuk menghapus residu ini)"
    }
    let regCode = extra[MGKey.regionCode] as? String ?? ""
    if regCode == "LL",
       case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: dict, checkWapiSlot: true),
       let wOff = layout.wapiOffset,
       data[wOff] == 1 {
        return "Terdeteksi wilayah penjualan sudah dalam versi AS (LL), tetapi lapisan bawah masih membawa penanda WAPI yang unik untuk hardware versi Tiongkok (menunjukkan perangkat sudah pernah diubah wilayahnya sebelum aplikasi ini dipasang)"
    }
    return nil
}

/// Ensures `OriginalGestalt.plist` exists cleanly:
/// - Recovers true factory backup from SystemGroup vault across sideload app uninstall/reinstall;
/// - Mirrors valid local backup into SystemGroup vault if missing;
/// - Warns if first-ever install encounters an already-modified system plist.
func mgEnsureOriginalBackupWithVault(liveData: Data) throws -> (recoveredFromVault: Bool, suspectedDirtyWarning: String?) {
    let liveDict = (try? PropertyListSerialization.propertyList(from: liveData, options: [], format: nil) as? NSDictionary) ?? [:]
    let liveBuild = liveDict["CacheVersion"] as? String ?? ""
    let liveUUID = liveDict["CacheUUID"] as? String ?? ""
    let kernelHW = machineName()

    let fm = FileManager.default
    if fm.fileExists(atPath: MGURL.savedGestaltURL.path) {
        if !fm.fileExists(atPath: MGURL.savedGestaltSHA256URL.path),
           let existingOgData = try? Data(contentsOf: MGURL.savedGestaltURL),
           mgValidatePlistData(existingOgData).0 {
            let hex = mgComputeSHA256Hex(existingOgData)
            try? Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
            mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
        }
        mgExcludeFromCloudBackup(MGURL.savedGestaltURL)

        // Sync to SystemGroup vault if vault is missing or outdated while local backup matches live OS build
        if mgVerifyOriginalBackupIntegrity().0,
           let localData = try? Data(contentsOf: MGURL.savedGestaltURL),
           let localDict = NSDictionary(contentsOf: MGURL.savedGestaltURL) {
            let localBuild = localDict["CacheVersion"] as? String ?? ""
            let vaultValid = mgHasSyncedSystemVault()
            let vaultBuild = (NSDictionary(contentsOf: MGURL.systemVaultGestaltURL)?["CacheVersion"] as? String) ?? ""
            if !vaultValid || (!localBuild.isEmpty && localBuild == liveBuild && vaultBuild != liveBuild) {
                mgSyncSystemVaultBackup(localData, hexDigest: mgComputeSHA256Hex(localData))
            }
        }
        return (false, nil)
    }

    // Documents/OriginalGestalt.plist is missing (first install OR sideload uninstall+reinstall):
    // Try recovering from SystemGroup vault first!
    let vaultDir = MGURL.systemVaultGestaltURL.deletingLastPathComponent()
    if !fm.isReadableFile(atPath: vaultDir.path) {
        _ = wq.grantAccess(path: vaultDir.path)
    }
    if mgHasSyncedSystemVault(),
       let vaultData = try? Data(contentsOf: MGURL.systemVaultGestaltURL),
       let vaultDict = try? PropertyListSerialization.propertyList(from: vaultData, options: [], format: nil) as? NSDictionary {
        let vaultBuild = vaultDict["CacheVersion"] as? String ?? ""
        let vaultUUID = vaultDict["CacheUUID"] as? String ?? ""
        let vaultExtra = vaultDict["CacheExtra"] as? NSDictionary
        let vaultProd = vaultExtra?[MGKey.prodType] as? String ?? ""
        let vaultLen = (vaultDict["CacheData"] as? Data)?.count ?? 0
        let liveLen = (liveDict["CacheData"] as? Data)?.count ?? 0

        let hwMatches = vaultProd.isEmpty || kernelHW.isEmpty || vaultProd == kernelHW
        let buildMatches = !vaultBuild.isEmpty && vaultBuild == liveBuild
        let uuidMatches = !vaultUUID.isEmpty && vaultUUID.caseInsensitiveCompare(liveUUID) == .orderedSame
        let lenMatches = vaultLen > 0 && vaultLen == liveLen

        if hwMatches && buildMatches && uuidMatches && lenMatches {
            let hex = mgComputeSHA256Hex(vaultData)
            try vaultData.write(to: MGURL.savedGestaltURL, options: .atomic)
            mgExcludeFromCloudBackup(MGURL.savedGestaltURL)
            try Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
            mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
            print("[*] (mg-vault) Terdeteksi instalasi ulang aplikasi, telah memulihkan cadangan pabrik secara lossless dari vault keamanan sistem (\(vaultBuild))!")
            return (true, nil)
        }
    }

    // True first-ever backup on this OS build: inspect whether system plist was already modified by another tool
    let dirtyReason = mgDetectSuspectedThirdPartyModification(in: liveDict)
    try mgSaveOriginalBackupWithDigest(liveData)
    return (false, dirtyReason)
}

func mgImportExternalOriginalBackup(from externalURL: URL) -> Result<String, Error> {
    let scoped = externalURL.startAccessingSecurityScopedResource()
    defer {
        if scoped { externalURL.stopAccessingSecurityScopedResource() }
    }
    do {
        let data = try Data(contentsOf: externalURL)
        let preCheck = mgValidatePlistData(data)
        guard preCheck.0,
              let importedDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary else {
            throw NSError(domain: "Erosion.MGImport", code: 1, userInfo: [NSLocalizedDescriptionKey: preCheck.1])
        }

        let impExtra = importedDict["CacheExtra"] as? NSDictionary
        let impProd = impExtra?[MGKey.prodType] as? String ?? ""
        let kernelHW = machineName()
        if !impProd.isEmpty && !kernelHW.isEmpty && impProd != kernelHW {
            throw NSError(domain: "Erosion.MGImport", code: 2, userInfo: [NSLocalizedDescriptionKey: "Impor ditolak: model cadangan (\(impProd)) tidak cocok dengan hardware asli perangkat ini (\(kernelHW))!"])
        }

        let vaultDir = MGURL.fsGestaltURL.deletingLastPathComponent()
        if !FileManager.default.isReadableFile(atPath: vaultDir.path) {
            _ = wq.grantAccess(path: vaultDir.path)
        }
        if let liveDict = NSDictionary(contentsOf: MGURL.fsGestaltURL) {
            let impBuild = importedDict["CacheVersion"] as? String ?? ""
            let liveBuild = liveDict["CacheVersion"] as? String ?? ""
            if !impBuild.isEmpty && !liveBuild.isEmpty && impBuild != liveBuild {
                throw NSError(domain: "Erosion.MGImport", code: 3, userInfo: [NSLocalizedDescriptionKey: "Impor ditolak: versi sistem cadangan (\(impBuild)) tidak cocok dengan sistem saat ini (\(liveBuild))!"])
            }
            let impUUID = importedDict["CacheUUID"] as? String ?? ""
            let liveUUID = liveDict["CacheUUID"] as? String ?? ""
            if !impUUID.isEmpty && !liveUUID.isEmpty && impUUID.caseInsensitiveCompare(liveUUID) != .orderedSame {
                throw NSError(domain: "Erosion.MGImport", code: 4, userInfo: [NSLocalizedDescriptionKey: "Impor ditolak: CacheUUID cadangan tidak cocok dengan sistem saat ini!"])
            }
            let impLen = (importedDict["CacheData"] as? Data)?.count ?? 0
            let liveLen = (liveDict["CacheData"] as? Data)?.count ?? 0
            if impLen > 0 && liveLen > 0 && impLen != liveLen {
                throw NSError(domain: "Erosion.MGImport", code: 5, userInfo: [NSLocalizedDescriptionKey: "Impor ditolak: panjang byte CacheData cadangan (\(impLen)) tidak cocok dengan sistem saat ini (\(liveLen))!"])
            }
        }

        if FileManager.default.fileExists(atPath: MGURL.savedGestaltURL.path) {
            let archiveURL = URL.documentsDirectory.appendingPathComponent("ArchivedOriginalGestalt_\(Int(Date().timeIntervalSince1970)).plist")
            try? FileManager.default.copyItem(at: MGURL.savedGestaltURL, to: archiveURL)
            mgExcludeFromCloudBackup(archiveURL)
        }

        try mgSaveOriginalBackupWithDigest(data)
        let buildStr = (importedDict["CacheVersion"] as? String) ?? "Versi Saat Ini"
        let shaPrefix = String(mgComputeSHA256Hex(data).prefix(12))
        return .success("Berhasil memverifikasi dan mengimpor cadangan pabrik (versi: \(buildStr), model: \(impProd), SHA-256: \(shaPrefix)...), dan sekaligus disinkronkan dan dikunci ke vault keamanan sistem.")
    } catch {
        return .failure(error)
    }
}

func mgResetLocalTweakPreferences() {
    let ud = UserDefaults.standard
    if let raw = ud.string(forKey: "mgCustKeyArray"),
       var arr = [MGCustomKey](rawValue: raw) {
        for idx in arr.indices {
            arr[idx].isOn = false
        }
        ud.set(arr.rawValue, forKey: "mgCustKeyArray")
    }
    ud.set("", forKey: "mgDeviceName")
    ud.set(false, forKey: "mgOverrideGates")
    ud.removeObject(forKey: MGRegionUnlockMode.defaultsKey)
}

func mgExecuteCleanCacheRebuild(alsoResetConfigAndKeypad: Bool = false) -> Result<Void, Error> {
    let fm = FileManager.default
    let cacheDir = MGURL.fsGestaltURL.deletingLastPathComponent()
    if !fm.isWritableFile(atPath: cacheDir.path) {
        _ = wq.grantAccess(path: cacheDir.path)
    }
    do {
        if fm.fileExists(atPath: MGURL.savedGestaltURL.path) {
            let archiveURL = URL.documentsDirectory.appendingPathComponent("ArchivedOriginalGestalt_\(Int(Date().timeIntervalSince1970)).plist")
            try? fm.copyItem(at: MGURL.savedGestaltURL, to: archiveURL)
            mgExcludeFromCloudBackup(archiveURL)
            try? fm.removeItem(at: MGURL.savedGestaltURL)
        }
        try? fm.removeItem(at: MGURL.savedGestaltSHA256URL)
        try? fm.removeItem(at: MGURL.systemVaultGestaltURL)
        try? fm.removeItem(at: MGURL.systemVaultSHA256URL)

        mgResetLocalTweakPreferences()
        if alsoResetConfigAndKeypad {
            try? ConfigView.resetSystemConfigSafely()
            _ = KeypadManager.shared.resetKeypadItems()
        }

        if fm.fileExists(atPath: MGURL.fsGestaltURL.path) {
            try fm.removeItem(at: MGURL.fsGestaltURL)
        }
        GestaltStore.shared.mgCurrentDict = NSMutableDictionary()
        return .success(())
    } catch {
        return .failure(error)
    }
}

func mgExecuteFactoryRestore(alsoResetConfigAndKeypad: Bool) -> MGFactoryRestoreOutcome {
    let fm = FileManager.default
    let cacheDir = MGURL.fsGestaltURL.deletingLastPathComponent()
    if !fm.isWritableFile(atPath: cacheDir.path) {
        let res = wq.grantAccess(path: cacheDir.path)
        if !res.0 && !fm.isWritableFile(atPath: cacheDir.path) {
            return .failed(reason: "Gagal mendapatkan izin tulis direktori MobileGestalt, harap keluar sepenuhnya dan buka kembali aplikasi ini sebelum mencoba lagi.")
        }
    }

    // If local Documents backup is missing, try recovering from SystemGroup vault first
    if !fm.fileExists(atPath: MGURL.savedGestaltURL.path),
       mgHasSyncedSystemVault(),
       let vaultData = try? Data(contentsOf: MGURL.systemVaultGestaltURL) {
        let hex = mgComputeSHA256Hex(vaultData)
        try? vaultData.write(to: MGURL.savedGestaltURL, options: .atomic)
        mgExcludeFromCloudBackup(MGURL.savedGestaltURL)
        try? Data(hex.utf8).write(to: MGURL.savedGestaltSHA256URL, options: .atomic)
        mgExcludeFromCloudBackup(MGURL.savedGestaltSHA256URL)
    }

    let integrityCheck = mgVerifyOriginalBackupIntegrity()
    guard integrityCheck.0 else {
        return .blockedNeedsCleanRebuild(
            title: "Cadangan asli hilang atau verifikasi gagal!",
            reason: "\(integrityCheck.1)\n\nAnda dapat memilih \"Bangun Ulang Cache Pabrik Bersih Sistem\" di bawah, agar iOS saat restart langsung meregenerasi parameter pabrik 100% dari fuse hardware motherboard."
        )
    }

    guard let mgDictToApply = NSMutableDictionary(contentsOf: MGURL.savedGestaltURL) else {
        return .blockedNeedsCleanRebuild(
            title: "Tidak dapat membaca cadangan asli!",
            reason: "File OriginalGestalt.plist yang valid tidak ditemukan. Anda dapat menggunakan \"Bangun Ulang Cache Pabrik Bersih Sistem\" di bawah untuk otomatis membangun ulang konfigurasi pabrik saat restart."
        )
    }

    if let liveDict = NSDictionary(contentsOf: MGURL.fsGestaltURL) {
        let ogBuild = mgDictToApply["CacheVersion"] as? String ?? ""
        let liveBuild = liveDict["CacheVersion"] as? String ?? ""
        if !ogBuild.isEmpty && !liveBuild.isEmpty && ogBuild != liveBuild {
            return .blockedNeedsCleanRebuild(
                title: "Pemblokiran aman penimpaan cadangan lintas versi iOS",
                reason: "Terdeteksi cadangan asli berasal dari sistem versi lama (\(ogBuild)), sedangkan sistem saat ini telah diperbarui ke \(liveBuild), layout slot biner telah berubah, penimpaan langsung berisiko.\n\nTekan \"Bangun Ulang Cache Pabrik Bersih Sistem\" di bawah untuk menghapus cache lama dengan aman, dan setelah restart sistem \(liveBuild) akan otomatis menghitung ulang parameter pabrik 100%!"
            )
        }

        let ogUUID = mgDictToApply["CacheUUID"] as? String ?? ""
        let liveUUID = liveDict["CacheUUID"] as? String ?? ""
        if !ogUUID.isEmpty && !liveUUID.isEmpty && ogUUID.caseInsensitiveCompare(liveUUID) != .orderedSame {
            return .blockedNeedsCleanRebuild(
                title: "Pemblokiran aman pemulihan CacheUUID yang tidak cocok",
                reason: "CacheUUID cadangan asli (\(ogUUID)) tidak cocok dengan sistem saat ini (\(liveUUID)), pagar pengaman telah memblokir penimpaan langsung.\n\nTekan \"Bangun Ulang Cache Pabrik Bersih Sistem\" dan restart untuk memulihkan status pabrik 100% dengan aman."
            )
        }

        let ogCacheLen = (mgDictToApply["CacheData"] as? Data)?.count ?? 0
        let liveCacheLen = (liveDict["CacheData"] as? Data)?.count ?? 0
        if ogCacheLen > 0 && liveCacheLen > 0 && ogCacheLen != liveCacheLen {
            return .blockedNeedsCleanRebuild(
                title: "Pemblokiran aman pemulihan cache biner dengan panjang tidak cocok",
                reason: "Panjang CacheData cadangan asli (\(ogCacheLen) byte) tidak cocok dengan sistem saat ini (\(liveCacheLen) byte), penulisan langsung diblokir!\n\nTekan \"Bangun Ulang Cache Pabrik Bersih Sistem\" dan restart untuk memulihkan status pabrik 100% dengan aman."
            )
        }

        let ogExtra = mgDictToApply["CacheExtra"] as? NSDictionary
        let ogProd = ogExtra?[MGKey.prodType] as? String ?? ""
        let actualHW = machineName()
        if !ogProd.isEmpty && !actualHW.isEmpty && ogProd != actualHW {
            return .blockedNeedsCleanRebuild(
                title: "Pemulihan cadangan lintas model diblokir!",
                reason: "Cadangan ini berasal dari model lain (\(ogProd)), tidak cocok dengan hardware asli perangkat ini (\(actualHW)), penulisan langsung akan menyebabkan soft-brick bootloop! Silakan tekan \"Bangun Ulang Cache Pabrik Bersih Sistem\" untuk memulihkan konfigurasi pabrik perangkat ini."
            )
        }
    }

    do {
        let data = try PropertyListSerialization.data(fromPropertyList: mgDictToApply, format: .binary, options: 0)
        let res = mgWriteDetailed(data, allowVerifiedFactoryRestore: true)
        guard res.0 else {
            return .failed(reason: res.1)
        }

        mgResetLocalTweakPreferences()
        var extraResetNotes: [String] = []
        if alsoResetConfigAndKeypad {
            if (try? ConfigView.resetSystemConfigSafely()) != nil {
                extraResetNotes.append("Teks layar kunci/plat nama aset dan residu pseudo-supervisi telah dibersihkan")
            }
            if KeypadManager.shared.resetKeypadItems() {
                extraResetNotes.append("Cache keypad dial kustom telah diatur ulang")
            }
        }

        if let freshBytes = try? Data(contentsOf: MGURL.fsGestaltURL),
           let freshDict = try? PropertyListSerialization.propertyList(from: freshBytes, options: [.mutableContainersAndLeaves], format: nil) as? NSMutableDictionary {
            GestaltStore.shared.mgCurrentDict = freshDict
        }

        var summary = MGMsg.revertComp
        if !extraResetNotes.isEmpty {
            summary += "\n\nItem pemulihan tambahan: " + extraResetNotes.joined(separator: "; ") + "."
        }
        return .restoredSuccessfully(details: summary)
    } catch {
        return .failed(reason: error.localizedDescription)
    }
}

func mgIsDangerousCacheExtraKey(_ key: String) -> String? {
    let blocked: [String: String] = [
        "zHeENZu+wbg7PUprwNwBWg": "RegionInfo (kunci bukan cache iOS 27, injeksi akan memicu reset cache boot)",
        "0L5PkT61qoH1b/B1USWqjQ": "RegionalBehaviorChinaBrick (kunci hardware bukan cache, injeksi akan memicu reset boot)",
        "gD8SNRcHQeIxCAvsp+2vjA": "WSKU (data kalibrasi RF radio, manipulasi dapat menyebabkan Wi-Fi/Bluetooth lumpuh)",
        "sFTm4FEVKVfdZ0ChdwQY1g": "WifiAntennaSKUVersion (parameter kalibrasi antena, dilarang dimanipulasi)",
        "91LyMcx4z1w3SGVeqteMnA": "BasebandRegionSKU (parameter RF baseband, manipulasi dapat menyebabkan deadlock baseband)",
        "iyfxmLogGVIaH7aEgqwcIA": "green-tea (milik slot biner CacheData, dilarang diinjeksi ke CacheExtra)",
        "4snMZS8LJkSctKypt2m+xA": "not-green-tea (milik slot biner CacheData, dilarang diinjeksi ke CacheExtra)",
        "hiHut/WR+B9Lx/vd0WyeNg": "wapi (milik slot biner CacheData, dilarang diinjeksi ke CacheExtra)",
        "green-tea": "green-tea (kunci konflik plaintext, dilarang diinjeksi ke CacheExtra)",
        "not-green-tea": "not-green-tea (kunci konflik plaintext, dilarang diinjeksi ke CacheExtra)",
        "wapi": "wapi (kunci konflik plaintext, dilarang diinjeksi ke CacheExtra)",
        "aVL5GE3tx0LSCI/ErfrJGA": "Audio Mix (milik slot biner CacheData, silakan langsung gunakan sakelar yang sesuai di antarmuka utama)",
        "X6NGcYcvHmbqlR8hLXASJA": "Perekaman Audio Spasial (milik slot biner CacheData, silakan langsung gunakan sakelar yang sesuai di antarmuka utama)",
        "/EVOCjM/Nmb2roP5ebtEFA": "Audio Spasial FaceTime (milik slot biner CacheData, silakan langsung gunakan sakelar yang sesuai di antarmuka utama)",
        "gQDt76Te0SPw7N8oTLrBFw": "Jepretan Seketika Saat Tombol Rana Ditekan (milik slot biner CacheData, silakan langsung gunakan sakelar yang sesuai di antarmuka utama)",
        "4fh9efw4o1yaFqkXNCXoeA": "Evaluasi Tren Hipertensi (milik slot biner CacheData, silakan langsung gunakan sakelar yang sesuai di antarmuka utama)",
        "CacheData": "Field Reserved Sistem Tingkat Atas",
        "CacheUUID": "Field Reserved Sistem Tingkat Atas",
        "CacheVersion": "Field Reserved Sistem Tingkat Atas"
    ]
    return blocked[key]
}

func mgWriteDetailed(_ data: Data, allowVerifiedFactoryRestore: Bool = false) -> (Bool, String) {
    let preCheck = mgValidatePlistData(data)
    guard preCheck.0 else {
        print("(mg) validasi pra-tulis gagal: \(preCheck.1)")
        return preCheck
    }

    guard let originalBytes = try? Data(contentsOf: MGURL.fsGestaltURL), !originalBytes.isEmpty else {
        let msg = "Gagal membaca file MobileGestalt asli perangkat saat ini (file kosong atau tidak ada izin), penulisan dihentikan untuk melindungi sistem!"
        print("(mg) \(msg)")
        return (false, msg)
    }

    // Strict pre-write CacheData verification:
    // - Normal edits enforce allowedOffsets transition check against liveDiskDict;
    // - SHA-256 verified factory backup restoration validates targetDict directly against loaded libMobileGestalt.dylib
    //   so even previously corrupted eSIM / cellular / ISP bytes in liveDiskDict can be healed back to factory state!
    if let liveDiskDict = try? PropertyListSerialization.propertyList(from: originalBytes, options: [], format: nil) as? NSDictionary,
       let targetDict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary {
        if allowVerifiedFactoryRestore {
            if case .failure(let targetErr) = MGCacheDataCoordinator.shared.resolveValidated(for: targetDict) {
                print("[!] (mg) Validasi CacheData target pemulihan pabrik gagal: \(targetErr.localizedDescription)")
                return (false, targetErr.localizedDescription)
            }
        } else {
            if case .failure(let cacheErr) = MGCacheDataCoordinator.shared.validateTransition(from: liveDiskDict, to: targetDict) {
                print("[!] (mg) Pemeriksaan pra-tulis CacheData menolak penulisan: \(cacheErr.localizedDescription)")
                return (false, cacheErr.localizedDescription)
            }
        }
    }

    // Save pre-apply snapshot before touching system file (excluded from iCloud/Finder device migration)
    try? originalBytes.write(to: MGURL.preApplyGestaltURL, options: .atomic)
    mgExcludeFromCloudBackup(MGURL.preApplyGestaltURL)

    // Unconditionally enforce safe in-place write (pwrite + tail truncate + F_FULLFSYNC) to preserve Inode & POSIX attributes
    let res = writeFileAtomically(data, to: MGURL.fsGestaltURL)
    if !res.0 {
        print("(mg) penulisan gagal: \(res.1)")
        return (false, "Gagal menulis file sistem: \(res.1)")
    }

    // Full readback & plist structural/type verification
    do {
        let readbackBytes = try Data(contentsOf: MGURL.fsGestaltURL)
        let readbackCheck = mgValidatePlistData(readbackBytes)
        guard readbackBytes == data,
              readbackCheck.0,
              let expectedDict = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? NSDictionary,
              let actualDict = try PropertyListSerialization.propertyList(from: readbackBytes, options: [], format: nil) as? NSDictionary,
              mgPlistValuesEqual(expectedDict, actualDict) else {
            throw NSError(domain: "Erosion.MGVerify", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data baca balik dari disk tidak cocok dengan nilai/tipe kunci yang diharapkan"])
        }
        print("(mg) baca balik terverifikasi (\(readbackBytes.count) byte)")
        return (true, "succeeded")
    } catch {
        print("(mg) verifikasi baca balik gagal (\(error.localizedDescription))! Mengembalikan byte sebelumnya...")
        let rollbackOK = writeFileAtomically(originalBytes, to: MGURL.fsGestaltURL).0
        let verifiedRollback = ((try? Data(contentsOf: MGURL.fsGestaltURL)) == originalBytes)
        if rollbackOK && verifiedRollback {
            return (false, "Verifikasi baca balik pasca-tulis gagal (\(error.localizedDescription)), telah otomatis rollback aman ke keadaan sebelum modifikasi secara in-place!")
        } else {
            return (false, "Verifikasi baca balik pasca-tulis gagal dan rollback otomatis juga anomali, jangan restart dan pergi ke pengaturan lanjutan untuk memeriksa cache!")
        }
    }
}

func mgWrite(_ data: Data) -> Bool {
    return mgWriteDetailed(data).0
}

func currentOriginalMachineName() -> String {
    if let saved = UserDefaults.standard.string(forKey: "ogMachineName"), !saved.isEmpty {
        return saved
    }
    return machineName()
}

/// Returns the true factory hardware ProductType (immune to in-memory or active ProductType spoofing)
func originalHardwareProductType() -> String {
    if let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
       let ogExtra = ogDict["CacheExtra"] as? NSDictionary,
       let ogProd = ogExtra[MGKey.prodType] as? String,
       !ogProd.isEmpty {
        return ogProd
    }
    return currentOriginalMachineName()
}

// MARK: - Safe Read-Only Live MGCopyAnswer Probe (+1 Copy Rule Compliant)

private typealias MGCopyAnswerFn = @convention(c) (CFString) -> Unmanaged<CFTypeRef>?

private let resolvedMGCopyAnswer: MGCopyAnswerFn? = {
    let handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY | RTLD_LOCAL)
    guard let sym = dlsym(handle ?? UnsafeMutableRawPointer(bitPattern: -2), "MGCopyAnswer") else {
        return nil
    }
    return unsafeBitCast(sym, to: MGCopyAnswerFn.self)
}()

func mgQueryLiveRaw(forKey key: String) -> CFTypeRef? {
    #if os(iOS) && !targetEnvironment(simulator)
    guard let fn = resolvedMGCopyAnswer, !key.isEmpty else { return nil }
    // MGCopyAnswer follows CoreFoundation's +1 Copy rule; takeRetainedValue() transfers ownership to ARC without leaking
    return fn(key as CFString)?.takeRetainedValue()
    #else
    return nil
    #endif
}

func mgQueryLiveBool(forKey key: String) -> Bool? {
    guard let val = mgQueryLiveRaw(forKey: key) else { return nil }
    let typeID = CFGetTypeID(val)
    if typeID == CFBooleanGetTypeID() {
        return CFBooleanGetValue((val as! CFBoolean))
    }
    if let num = val as? NSNumber {
        return num.boolValue
    }
    return nil
}

func mgQueryLiveString(forKey key: String) -> String? {
    guard let val = mgQueryLiveRaw(forKey: key) else { return nil }
    return val as? String
}

func mgQueryLiveFormatted(forKey key: String) -> String {
    guard let val = mgQueryLiveRaw(forKey: key) else {
        return "nil (tidak dikembalikan / default nonaktif)"
    }
    let typeID = CFGetTypeID(val)
    if typeID == CFBooleanGetTypeID() {
        return CFBooleanGetValue((val as! CFBoolean)) ? "true (Bool)" : "false (Bool)"
    }
    if let num = val as? NSNumber {
        if CFNumberIsFloatType(num) {
            return "\(num.doubleValue) (Float)"
        }
        return "\(num.stringValue) (Int)"
    }
    if let str = val as? String {
        return str.isEmpty ? "\"\"" : str
    }
    if let data = val as? Data {
        return "<Data: \(data.count) byte>"
    }
    if let arr = val as? NSArray {
        return "<Array: \(arr.count) item>"
    }
    if let dict = val as? NSDictionary {
        return "<Dict: \(dict.count) item>"
    }
    return String(describing: val)
}

/// Maps Mainland China / International models & ProductTypes to US (LL/A) RegulatoryModelNumber (97JDvERpVwO+GHtthIh7hA)
func usRegulatoryModelNumber(productType: String, originalRegModel: String = "") -> String? {
    let regModelMap: [String: String] = [
        // iPhone 18 / Duo Series (China / HK / Intl -> US)
        "A3718": "A3473", "A3717": "A3473", "A3716": "A3473", // iPhone 18 Pro Max -> US A3473
        "A3715": "A3472", "A3714": "A3472", "A3713": "A3472", // iPhone 18 Pro -> US A3472
        "A3721": "A3447", "A3720": "A3447", "A3719": "A3447", // iPhone Duo -> US A3447
        // iPhone 17 / Air / 17e Series
        "A3520": "A3258", "A3519": "A3258",                   // iPhone 17 -> US A3258
        "A3523": "A3256", "A3522": "A3256",                   // iPhone 17 Pro -> US A3256
        "A3526": "A3257", "A3525": "A3257",                   // iPhone 17 Pro Max -> US A3257
        "A3518": "A3260", "A3517": "A3260",                   // iPhone Air -> US A3260
        "A3635": "A3575", "A3634": "A3575",                   // iPhone 17e -> US A3575
        // iPhone 16 / 16e Series
        "A3288": "A3081", "A3287": "A3081",                   // iPhone 16 -> US A3081
        "A3291": "A3082", "A3290": "A3082",                   // iPhone 16 Plus -> US A3082
        "A3294": "A3083", "A3293": "A3083",                   // iPhone 16 Pro -> US A3083
        "A3297": "A3084", "A3296": "A3084",                   // iPhone 16 Pro Max -> US A3084
        "A3410": "A3212", "A3409": "A3212",                   // iPhone 16e -> US A3212
        // iPhone 15 Series
        "A3092": "A2846", "A3090": "A2846",                   // iPhone 15 -> US A2846
        "A3096": "A2847", "A3094": "A2847",                   // iPhone 15 Plus -> US A2847
        "A3104": "A2848", "A3102": "A2848",                   // iPhone 15 Pro -> US A2848
        "A3108": "A2849", "A3106": "A2849"                    // iPhone 15 Pro Max -> US A2849
    ]
    
    if let mapped = regModelMap[originalRegModel] {
        return mapped
    }
    
    let productTypeMap: [String: String] = [
        // iPhone 14 Series
        "iPhone14,7": "A2649",
        "iPhone14,8": "A2632",
        "iPhone15,2": "A2650",
        "iPhone15,3": "A2651",
        // iPhone 15 Series
        "iPhone15,4": "A2846",
        "iPhone15,5": "A2847",
        "iPhone16,1": "A2848",
        "iPhone16,2": "A2849",
        // iPhone 16 Series
        "iPhone17,1": "A3083",
        "iPhone17,2": "A3084",
        "iPhone17,3": "A3081",
        "iPhone17,4": "A3082",
        "iPhone17,5": "A3212",
        // iPhone 17 / Air / 17e Series
        "iPhone18,1": "A3256",
        "iPhone18,2": "A3257",
        "iPhone18,3": "A3258",
        "iPhone18,4": "A3260",
        "iPhone18,5": "A3575",
        // iPhone 18 / Duo Series (including regional/China board ProductTypes)
        "iPhone19,1": "A3471",
        "iPhone19,2": "A3472",
        "iPhone19,3": "A3473",
        "iPhone19,4": "A3447",
        "iPhone19,5": "A3471",
        "iPhone19,6": "A3472",
        "iPhone19,7": "A3473",
        "iPhone19,8": "A3447",
        // Apple Intelligence iPads
        "iPad13,4": "A2377", "iPad13,5": "A2301", "iPad13,6": "A2301", "iPad13,7": "A2301",
        "iPad13,8": "A2378", "iPad13,9": "A2379", "iPad13,10": "A2379", "iPad13,11": "A2379",
        "iPad13,16": "A2588", "iPad13,17": "A2589",
        "iPad14,3": "A2759", "iPad14,4": "A2435",
        "iPad14,5": "A2436", "iPad14,6": "A2764",
        "iPad14,8": "A2902", "iPad14,9": "A2903",
        "iPad14,10": "A2898", "iPad14,11": "A2899",
        "iPad15,3": "A3266", "iPad15,4": "A3267",
        "iPad15,5": "A3268", "iPad15,6": "A3269",
        "iPad16,1": "A2993", "iPad16,2": "A2995",
        "iPad16,3": "A2836", "iPad16,4": "A2837",
        "iPad16,5": "A2925", "iPad16,6": "A2926"
    ]
    
    return productTypeMap[productType]
}

/// Maps Mainland China hardware ProductType back to factory Mainland China (CH/A) RegulatoryModelNumber
/// when OriginalGestalt.plist was previously polluted with a US regulatory model by an external tool.
func chinaRegulatoryModelNumber(productType: String) -> String? {
    let chinaMap: [String: String] = [
        // iPhone 15 Series
        "iPhone15,4": "A3092",
        "iPhone15,5": "A3096",
        "iPhone16,1": "A3104",
        "iPhone16,2": "A3108",
        // iPhone 16 / 16e Series
        "iPhone17,1": "A3294",
        "iPhone17,2": "A3297",
        "iPhone17,3": "A3288",
        "iPhone17,4": "A3291",
        "iPhone17,5": "A3410",
        // iPhone 17 / Air / 17e Series
        "iPhone18,1": "A3523",
        "iPhone18,2": "A3526",
        "iPhone18,3": "A3520",
        "iPhone18,4": "A3518",
        "iPhone18,5": "A3635",
        // iPhone 18 / Duo Series
        "iPhone19,2": "A3715", "iPhone19,6": "A3715",
        "iPhone19,3": "A3718", "iPhone19,7": "A3718",
        "iPhone19,4": "A3721", "iPhone19,8": "A3721"
    ]
    return chinaMap[productType]
}

// device info getters
// HD - hardware device
func isDynamIslandHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isAODHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,2", "iPhone15,3", "iPhone16,1", "iPhone16,2", "iPhone17,1", "iPhone17,2", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isChargeLimitHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5", "iPad16,1", "iPad16,2", "iPad15,7", "iPad15,8", "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11", "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6", "iPad16,8", "iPad16,9", "iPad16,10", "iPad16,11", "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6", "iPad17,1", "iPad17,2", "iPad17,3", "iPad17,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isBootChimeHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,1", "iPhone18,2", "iPhone18,3", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isHomeButtonHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices: [String] = ["iPhone12,8", "iPhone14,6"]
    return hdDevices.contains(m)
}

// fun...
func isAppleIntellHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5", "iPad16,1", "iPad16,2", "iPad13,16", "iPad13,17", "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11", "iPad14,3", "iPad14,4", "iPad14,5", "iPad14,6", "iPad14,8", "iPad14,9", "iPad14,10", "iPad14,11", "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6", "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6", "iPad16,8", "iPad16,9", "iPad16,10", "iPad16,11", "iPad17,1", "iPad17,2", "iPad17,3", "iPad17,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isAudioIntellFirmwareSupported() -> Bool {
    if case .success(let layout) = MGCacheDataLayout.resolveFromLoadedLibrary(),
       layout.slotIndex(forKey: MGKey.audioIntell) != nil {
        return true
    }
    return mgQueryLiveRaw(forKey: MGKey.audioIntell) != nil
}

func isAdvAppleIntellFirmwareSupported() -> Bool {
    if case .success(let layout) = MGCacheDataLayout.resolveFromLoadedLibrary() {
        return MGKey.advAppIntellKeys.contains { layout.slotIndex(forKey: $0) != nil }
    }
    return MGKey.advAppIntellKeys.contains { mgQueryLiveRaw(forKey: $0) != nil }
}

func isNativeAudioIntellHD() -> Bool {
    let m = currentOriginalMachineName()
    if m.hasPrefix("iPhone") || m.hasPrefix("iPad") {
        return false
    }
    if let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
       case .success((let layout, _)) = MGCacheDataCoordinator.shared.resolveValidated(for: ogDict),
       layout.slotIndex(forKey: MGKey.audioIntell) != nil {
        return MGCacheDataCoordinator.shared.originalSlotValue(forKey: MGKey.audioIntell, layout: layout, savedOriginalDict: ogDict) == true
    }
    return false
}

func isNativePersonalTranslatorHD() -> Bool {
    guard isAppleIntellHD() else { return false }
    if case .success(let layout) = MGCacheDataCoordinator.shared.libraryLayout(),
       let slotIdx = layout.slotIndex(forKey: MGKey.personalTranslator) {
        if let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL) {
            if let val = MGCacheDataCoordinator.shared.originalSlotValue(forKey: MGKey.personalTranslator, layout: layout, savedOriginalDict: ogDict) {
                return val
            }
            if let ogData = ogDict["CacheData"] as? Data,
               ogData.count == layout.byteCount,
               layout.validateSingleBooleanSlot(slotIdx, in: ogData) {
                return ogData[slotIdx * 8] == 1
            }
        }
        if let recorded = MGCacheDataCoordinator.shared.originalSlotValue(forKey: MGKey.personalTranslator, layout: layout, savedOriginalDict: nil) {
            return recorded
        }
    }
    return currentOriginalMachineName().hasPrefix("iPhone19,")
}

func isAdvAISlotNativeTrue(_ key: String, layout: MGCacheDataLayout, savedOrig: NSDictionary?) -> Bool {
    let m = currentOriginalMachineName()
    // Ground-truth verified via MGInspector on live iPhone 18 Pro Max (iPhone19,7) running iOS 27:
    // - rb2tKZxlj0Gm2tBmUQSLqQ (Audio Intelligence, slot #178) is natively FALSE (0x00) on iPhone/iPad,
    //   and forcing it to 1 breaks Photos High-Quality Clean Up ("Terjadi kesalahan saat menghapus foto ini. Silakan coba lagi nanti.").
    // - M1n2sAqf33NAOgZRGxQYBA (Personal Translator, slot #266) IS natively TRUE (0x01) on iPhone 18 Pro series (iPhone19,*)
    //   in factory OriginalGestalt.plist, and works natively with Photos High-Quality Clean Up.
    if key == MGKey.audioIntell && (m.hasPrefix("iPhone") || m.hasPrefix("iPad")) {
        return false
    }
    if key == MGKey.personalTranslator {
        guard isAppleIntellHD() else { return false }
        if let val = MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) {
            return val
        }
        if let ogData = savedOrig?["CacheData"] as? Data,
           ogData.count == layout.byteCount,
           let slotIdx = layout.slotIndex(forKey: key),
           layout.validateSingleBooleanSlot(slotIdx, in: ogData) {
            return ogData[slotIdx * 8] == 1
        }
        return m.hasPrefix("iPhone19,")
    }
    return MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) ?? false
}

func isLiveAdvAIConflictActive() -> Bool {
    if isAdvAppleIntellHD() {
        return false
    }
    let nativePersonalTranslator = isNativePersonalTranslatorHD()
    let nativeAudioIntell = isNativeAudioIntellHD()
    return (!nativePersonalTranslator && (mgQueryLiveBool(forKey: MGKey.personalTranslator) ?? false))
        || (!nativeAudioIntell && (mgQueryLiveBool(forKey: MGKey.audioIntell) ?? false))
}

func isAdvAppleIntellHD() -> Bool {
    let m = currentOriginalMachineName()
    if m.hasPrefix("iPhone") || m.hasPrefix("iPad") {
        return false
    }
    if GestaltStore.shared.isSlotRulesNativeSatisfied(MGKey.advAppIntellRules) {
        return true
    }
    if let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
       case .success((let layout, _)) = MGCacheDataCoordinator.shared.resolveValidated(for: ogDict) {
        let presentKeys = MGKey.advAppIntellKeys.filter { layout.slotIndex(forKey: $0) != nil }
        if !presentKeys.isEmpty,
           presentKeys.allSatisfy({ MGCacheDataCoordinator.shared.originalSlotValue(forKey: $0, layout: layout, savedOriginalDict: ogDict) == true }) {
            return true
        }
    }
    return false
}

func isCrashDectHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone14,7", "iPhone14,8", "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5", "iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isPWMHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isCamControlHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}

func isActionButtonHD() -> Bool {
    let m = currentOriginalMachineName()
    let hdDevices = ["iPhone16,1", "iPhone16,2", "iPhone17,3", "iPhone17,4", "iPhone17,1", "iPhone17,2", "iPhone17,5", "iPhone18,3", "iPhone18,1", "iPhone18,2", "iPhone18,4", "iPhone18,5"]
    return hdDevices.contains(m) || m.hasPrefix("iPhone19,")
}
