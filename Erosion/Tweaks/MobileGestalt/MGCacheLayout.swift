//
//  MGCacheLayout.swift
//  Erosion
//
//  Strict runtime MobileGestalt CacheData descriptor resolver and byte-level validator.
//  Resolves offsets exclusively from the running device's loaded /usr/lib/libMobileGestalt.dylib.
//  Any ambiguity, mismatch, or validation failure strictly blocks modification.
//

import Foundation

struct MGSlotDescriptorInfo: Identifiable, Equatable, Sendable {
    var id: String { "\(slotIndex):\(obfuscatedKey)" }
    let obfuscatedKey: String
    let slotIndex: Int       // -1 for non-cached queries, 0..<slotCount for CacheData slots
    let queryType: UInt32    // 11 = Boolean
    var valueOffset: Int? { slotIndex >= 0 ? slotIndex * 8 : nil }

    func validityOffset(slotCount: Int) -> Int? {
        guard slotIndex >= 0 else { return nil }
        return slotCount * 8 + slotIndex
    }
}

struct MGCacheDataLayout: Codable, Equatable, Sendable {
    static let greenTeaKey = "iyfxmLogGVIaH7aEgqwcIA"      // green-tea
    static let notGreenTeaKey = "4snMZS8LJkSctKypt2m+xA"   // not-green-tea
    static let wapiKey = "hiHut/WR+B9Lx/vd0WyeNg"          // wapi (WLAN vs Wi-Fi)

    // Media, Camera & Health Boolean Slot Keys (IODeviceTree-backed, slot >= 0, qtype = 11)
    static let audioMixKey = "aVL5GE3tx0LSCI/ErfrJGA"            // CameracinematicAudioTrackRendering (Audio Mix)
    static let spatialAudioRecKey = "X6NGcYcvHmbqlR8hLXASJA"     // spatial-audio-recording
    static let spatialFaceTimeAudioKey = "/EVOCjM/Nmb2roP5ebtEFA"// spatial-facetime-audio
    static let responsiveShutterKey = "gQDt76Te0SPw7N8oTLrBFw"   // ResponsiveShutter
    static let hypertensionNotifKey = "4fh9efw4o1yaFqkXNCXoeA"   // HypertensionNotifications

    // Apple Intelligence & iOS 27 Advanced AI Boolean Slot Keys (slot >= 0, qtype = 11)
    static let appIntellKey = "A62OafQ85EJAiiqKn4agtg"           // DeviceSupportsGenerativeModelSystems
    static let photosCleanUpKey = "XNCjqOupLM/S8fNyxRNQTA"       // Photos Clean Up
    static let handwritingSynthKey = "YgYIIViDt1kgzyIsIV61vA"    // Handwriting Synthesis
    static let audioIntellKey = "rb2tKZxlj0Gm2tBmUQSLqQ"         // supports-audio-intelligence
    static let personalTranslatorKey = "M1n2sAqf33NAOgZRGxQYBA"  // supports-personal-translator

    // Promoted Existing Hardware & UI Boolean Slot Keys (verified slot >= 0, qtype = 11)
    static let islandKey = "YlEtTtHlNesRBMal1CqRaA"              // DeviceSupportsDynamicIsland
    static let aodKey = "2OOJf1VhaM7NxfRok3HbWQ"                 // DeviceSupportsAlwaysOnDisplay
    static let aoTimeKey = "j8/Omm6s1lsmTDFsXjsBfA"              // DeviceSupportsAlwaysOnTime
    static let aodVibrancyKey = "ykpu7qyhqFweVMKtxNylWA"         // DeviceSupportsAODVibrancy
    static let liquidGlassLowPowerKey = "SAGvsp6O6kAQ4fEfDJpC4Q" // DeviceSupportsLiquidGlassLowPower
    static let chargeLimKey = "37NVydb//GP/GrhuTN+exg"           // DeviceSupports80ChargeLimit
    static let bootChimeKey = "QHxt+hGLaBPbQJbXiUJX3w"           // DeviceSupportsBootChime
    static let crashDetKey = "HCzWusHQwZDea6nNhaKndw"            // DeviceSupportsCollisionSOS
    static let pwmKey = "6IejgN+1Fmu5/QrZFOIeNw"                 // DeviceSupportsPulseWidthMaximization
    static let appPencilKey = "yhHcB0iH0d1XzPO/CFd3ow"           // DeviceSupportsApplePencil
    static let camButtonKey = "CwvKxM2cEogD3p+HYgaW0Q"           // CameraButtonCapability
    static let actButtonKey = "cT44WE1EohiwRzhsZ8xEsw"           // RingerButtonCapability
    static let tapToWakeKey = "yZf3GTRMGTuwSV/lD7Cagw"           // DeviceSupportsTapToWake
    static let stageMgrKey = "qeaj75wk3HF4DwQ8qbIi7g"            // DeviceSupportsEnhancedMultitasking

    // [Fitur Uji] Newly Mined Experimental Boolean Slot Keys (100% verified slot >= 0, qtype = 11)
    static let shutterRelaxationKey = "P4ZJVy/zYuLy4ejRKP+0DA"          // DeviceSupportsRegionalCameraShutterRelaxation
    static let shutterKeyboardMutePreserveKey = "bGUN8lS6sYzy3xhePubp8A"// KeyboardMutePreservesRegionalShutterClickBehavior
    static let shutterLegacyMutePreserveKey = "Bim3FC83Te8QX1kfSpqYKQ"  // KeyboardMutePreservesRegionalShutterClickBehaviorForLegacyDevices
    static let concurrentHPLPMicsKey = "dI30ovtFUIeLioNQKDMbGQ"         // DeviceSupportsConcurrentHPLPMics
    static let photosLocalLightKey = "m9ORTKMgu9A+zF+A61Zz5A"           // DeviceSupportsPhotosLocalLight
    static let toneMappingKey = "Lcu6Zck+C/+AMO8qULacDw"                // DeviceSupportsToneMapping
    static let hdrDeferredProcessingKey = "JkZlE8z9YwHjE1hnbMhcgA"      // DeviceSupportsHDRDeferredProcessing
    static let spatialOverCaptureKey = "SjQQ07G8UacM7E69G7dPbg"         // DeviceSupportsSpatialOverCapture
    static let stereoAudioRecKey = "YlK+0xmxNWhNn/+r8SM8kA"             // DeviceSupportsStereoAudioRecording
    static let p3VideoRecKey = "1eBwtCIwbIDdC80wiyzfow"                 // DeviceSupportsP3ColorspaceVideoRecording
    static let touchSensitiveCamControlKey = "lyJZrSDc8J8eQ5Zb7A1Rvw"   // DeviceSupportsTouchSensitiveCameraControl
    static let hardwareDetentsKey = "V9pLLbPQhyb75bbdTioZVw"            // DeviceSupportsHardwareDetents
    static let cameraHapticsKey = "XriAxQ+JY1z5nt5f3ftXVw"              // DeviceSupportsCameraHaptics
    static let legacyBatteryInfoKey = "Rq0MF/w+gXM66Ii4fkWOzg"          // DeviceShowsBatteryModelInformationLegacyHW
    static let legacyDynamicEndOfChargeKey = "nfR1IphTGCaoFNu3NrCtWQ"   // DeviceSupportsDynamicEndOfChargeLegacyHW
    static let highLuminanceAODKey = "7brdL5xrEUWnlF9C0kdg5A"           // DeviceSupportsHighLuminanceAlwaysOnDisplay
    static let aodFlipbookKey = "aoJSd/MXk7M40NgXTM6x+g"                // DeviceSupportsAlwaysOnDisplayFlipbook
    static let carPlay2Key = "PR+xeEtTAiUN0R25+EYGfw"                   // DeviceSupportsCarPlay2
    static let touchDelivery120HzKey = "2OK50OGmkXM1ospsh766WQ"         // TouchDelivery120Hz
    static let hearingAidEQKey = "SMgTCc2v9AU2ziIHRX8qww"               // hearingaid-audio-equalization
    static let hearingAidLEKey = "RyXm3yMC4ejlFvwlEI509w"               // hearingaid-low-energy-audio
    static let hearingAidPowerRedKey = "u3c0R+31Df4SUTHrICQkTg"         // hearingaid-power-reduction
    static let breathingDisturbancesKey = "e0HV2blYUDBk/MsMEQACNA"      // DeviceSupportsBreathingDisturbancesMeasurements
    static let usBloodOxygenKey = "E4vGMChwcVRKD8hMVxnRvg"              // DeviceSupportsUSLegallyCompliantBloodOxygen
    static let workoutUltraKey = "fu+4kyf8VcMBtgbMyJlLtg"               // WorkoutUltraMode
    static let timeInDaylightKey = "8gVfz9/8R1OtWBBtI0o/+Q"             // DeviceSupportsTimeInDaylight
    static let siriHubKey = "waGD2UTpntjbDXD1r3oALQ"                    // DeviceSupportsSiriHub
    static let onDeviceSiriKey = "O/7gbXWA5X2IRPVtDRU+bw"               // OnDeviceSiriCapability
    static let modelPruningKey = "m4xs4mhvxnAopYrApoLDMw"               // DeviceSupportsInstructionFollowingPruningModels

    static let optionalFeatureSlotKeys: Set<String> = [
        audioMixKey,
        spatialAudioRecKey,
        spatialFaceTimeAudioKey,
        responsiveShutterKey,
        hypertensionNotifKey,
        appIntellKey,
        photosCleanUpKey,
        handwritingSynthKey,
        audioIntellKey,
        personalTranslatorKey,
        // Promoted existing toggles
        islandKey,
        aodKey,
        aoTimeKey,
        aodVibrancyKey,
        liquidGlassLowPowerKey,
        chargeLimKey,
        bootChimeKey,
        crashDetKey,
        pwmKey,
        appPencilKey,
        camButtonKey,
        actButtonKey,
        tapToWakeKey,
        stageMgrKey,
        // Newly mined experimental toggles
        shutterRelaxationKey,
        shutterKeyboardMutePreserveKey,
        shutterLegacyMutePreserveKey,
        concurrentHPLPMicsKey,
        photosLocalLightKey,
        toneMappingKey,
        hdrDeferredProcessingKey,
        spatialOverCaptureKey,
        stereoAudioRecKey,
        p3VideoRecKey,
        touchSensitiveCamControlKey,
        hardwareDetentsKey,
        cameraHapticsKey,
        legacyBatteryInfoKey,
        legacyDynamicEndOfChargeKey,
        highLuminanceAODKey,
        aodFlipbookKey,
        carPlay2Key,
        touchDelivery120HzKey,
        hearingAidEQKey,
        hearingAidLEKey,
        hearingAidPowerRedKey,
        breathingDisturbancesKey,
        usBloodOxygenKey,
        workoutUltraKey,
        timeInDaylightKey,
        siriHubKey,
        onDeviceSiriKey,
        modelPruningKey
    ]

    static let mediaHealthSlotKeys: Set<String> = [
        audioMixKey,
        spatialAudioRecKey,
        spatialFaceTimeAudioKey,
        responsiveShutterKey,
        hypertensionNotifKey
    ]

    let uuid: String
    let slotCount: Int
    let greenTeaIndex: Int
    let notGreenTeaIndex: Int
    let wapiIndex: Int?
    var featureSlotIndices: [String: Int] = [:]

    var byteCount: Int { slotCount * 9 }
    var greenTeaOffset: Int { greenTeaIndex * 8 }
    var notGreenTeaOffset: Int { notGreenTeaIndex * 8 }
    var wapiOffset: Int? { wapiIndex.map { $0 * 8 } }

    func slotIndex(forKey key: String) -> Int? {
        if key == Self.greenTeaKey { return greenTeaIndex }
        if key == Self.notGreenTeaKey { return notGreenTeaIndex }
        if key == Self.wapiKey { return wapiIndex }
        return featureSlotIndices[key]
    }

    func valueOffset(forKey key: String) -> Int? {
        return slotIndex(forKey: key).map { $0 * 8 }
    }

    func validityOffset(for slotIndex: Int) -> Int {
        return slotCount * 8 + slotIndex
    }

    var permittedMutableOffsets: Set<Int> {
        var set: Set<Int> = [greenTeaOffset, notGreenTeaOffset]
        if let wOff = wapiOffset {
            set.insert(wOff)
        }
        for (_, slotIdx) in featureSlotIndices where (0..<slotCount).contains(slotIdx) {
            set.insert(slotIdx * 8)
        }
        return set
    }

    // MARK: - Pure Runtime Descriptor Scanner (Zero Hardcoded Fallbacks)

    static func resolveFromLoadedLibrary() -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        #if os(iOS) && !targetEnvironment(simulator)
        guard let image = MGCopyLoadedMobileGestaltImage() else {
            return .failure(.libraryUnavailable("Tidak dapat memuat data segmen /usr/lib/libMobileGestalt.dylib dari memori secara read-only."))
        }
        return scan(image: image)
        #else
        return .failure(.libraryUnavailable("Lingkungan runtime saat ini bukan perangkat iOS asli, modifikasi CacheData biner dinonaktifkan."))
        #endif
    }

    static func scan(image: [String: Any]) -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        guard let strings = image["strings"] as? Data,
              let addressNum = image["stringAddress"] as? NSNumber,
              let constants = image["constants"] as? [Data] else {
            return .failure(.malformedImage("Citra pustaka sistem tidak memiliki data segmen __cstring atau __const yang diperlukan."))
        }
        let extraUUIDs = (image["cfUUIDs"] as? [String]) ?? []
        return scan(
            strings: strings,
            stringAddress: addressNum.uint64Value,
            constants: constants,
            extraUUIDs: extraUUIDs
        )
    }

    /// Scans modern 64-byte MobileGestalt query descriptors:
    /// +0x00: pointer to 22-char obfuscated key string (canonical 48-bit user VA)
    /// +0x3A: signed Int16 cache slot index
    /// +0x3C: UInt32 query type (11 = Boolean)
    static func scan(
        strings: Data,
        stringAddress: UInt64,
        constants: [Data],
        extraUUIDs: [String] = []
    ) -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        guard !strings.isEmpty,
              strings.count <= 32 * 1024 * 1024,
              stringAddress > 0,
              stringAddress <= UInt64.max - UInt64(strings.count),
              !constants.isEmpty,
              constants.count <= 8,
              constants.allSatisfy({ $0.count <= 32 * 1024 * 1024 }) else {
            return .failure(.malformedImage("Ukuran atau rentang alamat segmen pustaka sistem tidak normal, penguraian ditolak."))
        }

        var hashByAddress: [UInt64: String] = [:]
        var discoveredUUIDs = Set<String>()

        for u in extraUUIDs {
            if u.count == 36, let parsed = UUID(uuidString: u) {
                discoveredUUIDs.insert(parsed.uuidString.uppercased())
            }
        }

        strings.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = rawBuf.count
            var tokenStart = 0
            for idx in 0..<count where base[idx] == 0 {
                let len = idx - tokenStart
                if len == 22 {
                    var valid = true
                    for k in tokenStart..<idx {
                        let b = base[k]
                        if !((65...90).contains(b) || (97...122).contains(b) || (48...57).contains(b) || b == 43 || b == 47) {
                            valid = false
                            break
                        }
                    }
                    if valid {
                        let slice = UnsafeBufferPointer(start: base.advanced(by: tokenStart), count: 22)
                        hashByAddress[stringAddress + UInt64(tokenStart)] = String(decoding: slice, as: UTF8.self)
                    }
                } else if len == 36 {
                    let slice = UnsafeBufferPointer(start: base.advanced(by: tokenStart), count: 36)
                    if let text = String(bytes: slice, encoding: .utf8),
                       let parsedUUID = UUID(uuidString: text) {
                        discoveredUUIDs.insert(parsedUUID.uuidString.uppercased())
                    }
                }
                tokenStart = idx + 1
            }
        }

        guard !discoveredUUIDs.isEmpty else {
            return .failure(.uuidNotFound("Tidak dapat menemukan penanda CacheUUID yang unik di pustaka sistem, modifikasi ditolak."))
        }
        guard discoveredUUIDs.count == 1, let resolvedUUID = discoveredUUIDs.first else {
            return .failure(.ambiguousUUID("Ditemukan beberapa kandidat UUID di pustaka sistem (\(discoveredUUIDs.count) buah), menolak menebak offset!"))
        }

        var positiveIndices = Set<Int>()
        var targetIndices: [String: Set<Int>] = [:]
        var targetAlignments: [String: Set<String>] = [:]
        let requiredKeys: Set<String> = [greenTeaKey, notGreenTeaKey, wapiKey]

        for (secID, secData) in constants.enumerated() where secData.count >= 64 {
            let scanErr: MGCacheResolutionError? = secData.withUnsafeBytes { raw -> MGCacheResolutionError? in
                for off in stride(from: 0, through: secData.count - 64, by: 8) {
                    let rawPtr = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off, as: UInt64.self))
                    // Darwin arm64e userland VA space is 47-bit (0x0000_7FFF_FFFF_FFFF); strip bits 63:47 PAC tags
                    let canonicalPtr = rawPtr & 0x0000_7FFF_FFFF_FFFF
                    guard let key = hashByAddress[canonicalPtr] else { continue }

                    let slotIdx = Int(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3A, as: Int16.self)))
                    let queryType = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3C, as: UInt32.self))
                    guard (-1..<16384).contains(slotIdx), (1...11).contains(queryType) else { continue }

                    if slotIdx >= 0 {
                        positiveIndices.insert(slotIdx)
                    }

                    if requiredKeys.contains(key) {
                        guard queryType == 11, slotIdx >= 0 else {
                            return .invalidTargetDescriptor("Tipe deskriptor (\(queryType)) atau slot (\(slotIdx)) untuk kunci target \(key) bukan item cache boolean yang valid.")
                        }
                        targetIndices[key, default: []].insert(slotIdx)
                        targetAlignments[key, default: []].insert("\(secID):\(off % 64)")
                    } else if optionalFeatureSlotKeys.contains(key), queryType == 11, slotIdx >= 0 {
                        targetIndices[key, default: []].insert(slotIdx)
                        targetAlignments[key, default: []].insert("\(secID):\(off % 64)")
                    }
                }
                return nil
            }
            if let scanErr {
                return .failure(scanErr)
            }
        }

        guard let maxSlotIndex = positiveIndices.max(), maxSlotIndex >= 1 else {
            return .failure(.descriptorTableNotFound("Tidak dapat menemukan tabel deskriptor kueri MobileGestalt yang valid di pustaka sistem."))
        }
        let slotCount = maxSlotIndex + 1
        guard positiveIndices.count > slotCount / 2 else {
            return .failure(.sparseDescriptorTable("Cakupan slot tabel deskriptor tidak normal (\(positiveIndices.count)/\(slotCount)), penguraian ditolak."))
        }

        guard let gtSet = targetIndices[greenTeaKey], gtSet.count == 1, let gtIdx = gtSet.first,
              let ngtSet = targetIndices[notGreenTeaKey], ngtSet.count == 1, let ngtIdx = ngtSet.first,
              gtIdx != ngtIdx,
              (0..<slotCount).contains(gtIdx),
              (0..<slotCount).contains(ngtIdx),
              let gtAlign = targetAlignments[greenTeaKey], gtAlign.count == 1,
              gtAlign == targetAlignments[notGreenTeaKey] else {
            return .failure(.invalidTargetDescriptor("Tidak dapat menentukan secara unik slot cache green-tea / not-green-tea atau keselarasan tabel tidak konsisten, modifikasi ditolak."))
        }

        var resolvedWapiIdx: Int? = nil
        if let wapiSet = targetIndices[wapiKey] {
            guard wapiSet.count == 1,
                  let wIdx = wapiSet.first,
                  (0..<slotCount).contains(wIdx),
                  wIdx != gtIdx,
                  wIdx != ngtIdx,
                  targetAlignments[wapiKey] == gtAlign else {
                return .failure(.invalidTargetDescriptor("Deskriptor wapi ambigu atau keselarasan tidak konsisten, penguraian ditolak."))
            }
            resolvedWapiIdx = wIdx
        }

        var resolvedFeatureSlots: [String: Int] = [:]
        var usedCoreSlots: Set<Int> = [gtIdx, ngtIdx]
        if let wIdx = resolvedWapiIdx {
            usedCoreSlots.insert(wIdx)
        }
        for fKey in optionalFeatureSlotKeys.sorted() {
            if let fSet = targetIndices[fKey],
               fSet.count == 1,
               let fIdx = fSet.first,
               (0..<slotCount).contains(fIdx),
               !usedCoreSlots.contains(fIdx),
               targetAlignments[fKey] == gtAlign {
                resolvedFeatureSlots[fKey] = fIdx
            }
        }

        return .success(
            MGCacheDataLayout(
                uuid: resolvedUUID,
                slotCount: slotCount,
                greenTeaIndex: gtIdx,
                notGreenTeaIndex: ngtIdx,
                wapiIndex: resolvedWapiIdx,
                featureSlotIndices: resolvedFeatureSlots
            )
        )
    }

    static func scanDescriptorsFromLoadedLibrary() -> [MGSlotDescriptorInfo] {
        #if os(iOS) && !targetEnvironment(simulator)
        guard let image = MGCopyLoadedMobileGestaltImage(),
              let strings = image["strings"] as? Data,
              let addressNum = image["stringAddress"] as? NSNumber,
              let constants = image["constants"] as? [Data] else {
            return []
        }
        let stringAddress = addressNum.uint64Value
        var hashByAddress: [UInt64: String] = [:]
        strings.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.bindMemory(to: UInt8.self).baseAddress else { return }
            let count = rawBuf.count
            var tokenStart = 0
            for idx in 0..<count where base[idx] == 0 {
                let len = idx - tokenStart
                if len == 22 {
                    var valid = true
                    for k in tokenStart..<idx {
                        let b = base[k]
                        if !((65...90).contains(b) || (97...122).contains(b) || (48...57).contains(b) || b == 43 || b == 47) {
                            valid = false
                            break
                        }
                    }
                    if valid {
                        let slice = UnsafeBufferPointer(start: base.advanced(by: tokenStart), count: 22)
                        hashByAddress[stringAddress + UInt64(tokenStart)] = String(decoding: slice, as: UTF8.self)
                    }
                }
                tokenStart = idx + 1
            }
        }

        // Determine the primary descriptor table alignment from green-tea
        var expectedSecID: Int? = nil
        var expectedMod: Int? = nil
        for (secID, secData) in constants.enumerated() where secData.count >= 64 {
            secData.withUnsafeBytes { raw in
                for off in stride(from: 0, through: secData.count - 64, by: 8) {
                    let rawPtr = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off, as: UInt64.self))
                    let canonicalPtr = rawPtr & 0x0000_7FFF_FFFF_FFFF
                    if hashByAddress[canonicalPtr] == greenTeaKey {
                        let slotIdx = Int(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3A, as: Int16.self)))
                        let queryType = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3C, as: UInt32.self))
                        if slotIdx >= 0 && queryType == 11 {
                            expectedSecID = secID
                            expectedMod = off % 64
                            break
                        }
                    }
                }
            }
            if expectedSecID != nil { break }
        }

        var results: [MGSlotDescriptorInfo] = []
        var seenKeys = Set<String>()
        for (secID, secData) in constants.enumerated() where secData.count >= 64 {
            if let expSec = expectedSecID, expSec != secID { continue }
            secData.withUnsafeBytes { raw in
                for off in stride(from: 0, through: secData.count - 64, by: 8) {
                    if let expMod = expectedMod, (off % 64) != expMod { continue }
                    let rawPtr = UInt64(littleEndian: raw.loadUnaligned(fromByteOffset: off, as: UInt64.self))
                    let canonicalPtr = rawPtr & 0x0000_7FFF_FFFF_FFFF
                    guard let key = hashByAddress[canonicalPtr], !seenKeys.contains(key) else { continue }
                    let slotIdx = Int(Int16(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3A, as: Int16.self)))
                    let queryType = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: off + 0x3C, as: UInt32.self))
                    guard (-1..<16384).contains(slotIdx), (1...11).contains(queryType) else { continue }
                    seenKeys.insert(key)
                    results.append(MGSlotDescriptorInfo(obfuscatedKey: key, slotIndex: slotIdx, queryType: queryType))
                }
            }
        }
        return results
        #else
        return []
        #endif
    }

    // MARK: - Strict Plist & Byte-Level Verification

    func validatePlist(_ dict: NSDictionary, checkWapiSlot: Bool = false) -> Result<Data, MGCacheResolutionError> {
        guard (1...16384).contains(slotCount),
              (0..<slotCount).contains(greenTeaIndex),
              (0..<slotCount).contains(notGreenTeaIndex),
              greenTeaIndex != notGreenTeaIndex else {
            return .failure(.invalidTargetDescriptor("Indeks slot cache melebihi rentang yang sah."))
        }

        guard let plistUUID = dict["CacheUUID"] as? String, !plistUUID.isEmpty else {
            return .failure(.plistMismatch("File MobileGestalt tidak memiliki field CacheUUID, modifikasi ditolak."))
        }
        guard plistUUID.caseInsensitiveCompare(uuid) == .orderedSame else {
            return .failure(.plistMismatch("CacheUUID file cache (\(plistUUID)) tidak konsisten dengan pustaka sistem perangkat (\(uuid)), modifikasi ditolak!"))
        }

        guard let cacheData = dict["CacheData"] as? Data else {
            return .failure(.plistMismatch("File MobileGestalt tidak memiliki field CacheData biner, modifikasi ditolak."))
        }
        guard cacheData.count == byteCount else {
            return .failure(.plistMismatch("Panjang CacheData (\(cacheData.count) byte) tidak konsisten dengan panjang tepat yang dihitung pustaka sistem (\(byteCount) byte, \(slotCount) slot), modifikasi ditolak!"))
        }

        var slotsToVerify = [greenTeaIndex, notGreenTeaIndex]
        if let wIdx = wapiIndex {
            if checkWapiSlot || validateSingleBooleanSlot(wIdx, in: cacheData) {
                slotsToVerify.append(wIdx)
            }
        } else if checkWapiSlot {
            return .failure(.invalidTargetDescriptor("Pustaka sistem saat ini tidak mengurai slot wapi yang valid, modifikasi item ini ditolak."))
        }

        for slotIdx in slotsToVerify {
            let valOff = slotIdx * 8
            let validOff = validityOffset(for: slotIdx)
            guard validOff < cacheData.count, valOff + 8 <= cacheData.count else {
                return .failure(.plistMismatch("Offset slot \(slotIdx) di luar batas, modifikasi ditolak."))
            }
            guard cacheData[validOff] == 1 else {
                return .failure(.slotInvalid("Slot \(slotIdx) (offset bit valid 0x\(String(format: "%X", validOff))) tidak ditandai valid oleh sistem (validity != 1), modifikasi ditolak!"))
            }
            guard cacheData[valOff] <= 1 else {
                return .failure(.slotInvalid("Slot \(slotIdx) (offset 0x\(String(format: "%X", valOff))) memiliki nilai byte saat ini (\(cacheData[valOff])) bukan boolean yang sah (0/1), modifikasi ditolak!"))
            }
            for pad in (valOff + 1)..<(valOff + 8) {
                guard cacheData[pad] == 0 else {
                    return .failure(.slotInvalid("Byte padding slot \(slotIdx) tidak nol (offset 0x\(String(format: "%X", pad)) = \(cacheData[pad])), modifikasi ditolak!"))
                }
            }
        }

        if let extra = dict["CacheExtra"] as? NSDictionary {
            var forbiddenKeys = [Self.greenTeaKey, Self.notGreenTeaKey, "green-tea", "not-green-tea"]
            if checkWapiSlot {
                forbiddenKeys.append(contentsOf: [Self.wapiKey, "wapi"])
            }
            for k in forbiddenKeys where extra[k] != nil {
                return .failure(.conflictingCacheExtra("Terdeteksi kunci override \(k) sudah ada di CacheExtra, untuk memastikan keamanan modifikasi CacheData ditolak."))
            }
        }

        return .success(cacheData)
    }

    func validateSingleBooleanSlot(_ slotIdx: Int, in cacheData: Data) -> Bool {
        let valOff = slotIdx * 8
        let validOff = validityOffset(for: slotIdx)
        guard cacheData.count == byteCount,
              (0..<slotCount).contains(slotIdx),
              validOff < cacheData.count,
              valOff + 8 <= cacheData.count,
              cacheData[validOff] == 1,
              cacheData[valOff] <= 1 else {
            return false
        }
        return cacheData[(valOff + 1)..<(valOff + 8)].allSatisfy { $0 == 0 }
    }
}

enum MGCacheResolutionError: LocalizedError, Equatable {
    case libraryUnavailable(String)
    case malformedImage(String)
    case uuidNotFound(String)
    case ambiguousUUID(String)
    case descriptorTableNotFound(String)
    case sparseDescriptorTable(String)
    case invalidTargetDescriptor(String)
    case plistMismatch(String)
    case slotInvalid(String)
    case conflictingCacheExtra(String)
    case unauthorizedByteMutation(String)

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable(let m),
             .malformedImage(let m),
             .uuidNotFound(let m),
             .ambiguousUUID(let m),
             .descriptorTableNotFound(let m),
             .sparseDescriptorTable(let m),
             .invalidTargetDescriptor(let m),
             .plistMismatch(let m),
             .slotInvalid(let m),
             .conflictingCacheExtra(let m),
             .unauthorizedByteMutation(let m):
            return m
        }
    }
}

// MARK: - Original Per-UUID Flag Snapshot & Runtime Coordinator

struct MGCacheRecordedFlags: Codable, Equatable {
    let layoutUUID: String
    let cacheVersion: String
    let greenTea: Bool
    let notGreenTea: Bool
    let wapi: Bool?
    var extraSlots: [String: Bool]? = nil
}

struct MGCacheDataDiffDetail {
    let id: String
    let label: String
    let keyPath: String
    let beforeText: String
    let afterText: String
}

final class MGCacheDataCoordinator {
    static let shared = MGCacheDataCoordinator()

    private let defaultsKey = "mgRecordedOriginalCacheFlagsByUUID_v1"
    private let lock = NSLock()
    private var cachedVerifiedLayout: MGCacheDataLayout?
    private var cachedAllDescriptors: [MGSlotDescriptorInfo]?

    private init() {}

    func allDescriptors() -> [MGSlotDescriptorInfo] {
        lock.lock()
        if let existing = cachedAllDescriptors {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let scanned = MGCacheDataLayout.scanDescriptorsFromLoadedLibrary()
        if !scanned.isEmpty {
            lock.lock()
            cachedAllDescriptors = scanned
            lock.unlock()
        }
        return scanned
    }

    func libraryLayout() -> Result<MGCacheDataLayout, MGCacheResolutionError> {
        lock.lock()
        if let existing = cachedVerifiedLayout {
            lock.unlock()
            return .success(existing)
        }
        lock.unlock()

        let resolved = MGCacheDataLayout.resolveFromLoadedLibrary()
        if case .success(let layout) = resolved {
            lock.lock()
            cachedVerifiedLayout = layout
            lock.unlock()
        }
        return resolved
    }

    /// Resolves layout from live libMobileGestalt.dylib AND validates against the given plist dictionary.
    func resolveValidated(for dict: NSDictionary, checkWapiSlot: Bool = false) -> Result<(MGCacheDataLayout, Data), MGCacheResolutionError> {
        switch libraryLayout() {
        case .failure(let err):
            return .failure(err)
        case .success(let layout):
            switch layout.validatePlist(dict, checkWapiSlot: checkWapiSlot) {
            case .failure(let err):
                return .failure(err)
            case .success(let data):
                return .success((layout, data))
            }
        }
    }

    /// Records the earliest observed valid flags for a CacheUUID (preferring OriginalGestalt.plist if its UUID matches).
    func recordBaselineIfNeeded(liveDict: NSDictionary, savedOriginalDict: NSDictionary?) {
        // Prefer OriginalGestalt.plist if it matches this exact CacheUUID & layout
        if let saved = savedOriginalDict,
           case .success((let layout, let savedData)) = resolveValidated(for: saved) {
            saveInitialFlagsIfAbsent(from: saved, data: savedData, layout: layout)
            return
        }
        if case .success((let layout, let liveData)) = resolveValidated(for: liveDict) {
            saveInitialFlagsIfAbsent(from: liveDict, data: liveData, layout: layout)
        }
    }

    private func saveInitialFlagsIfAbsent(from dict: NSDictionary, data: Data, layout: MGCacheDataLayout) {
        lock.lock()
        defer { lock.unlock() }
        var map = loadRecordedMap()
        let key = layout.uuid.uppercased()

        var extraMap: [String: Bool] = [:]
        for (fKey, fSlot) in layout.featureSlotIndices where layout.validateSingleBooleanSlot(fSlot, in: data) {
            extraMap[fKey] = (data[fSlot * 8] == 1)
        }

        if var existing = map[key] {
            var currentExtra = existing.extraSlots ?? [:]
            var updated = false
            for (k, v) in extraMap where currentExtra[k] == nil {
                currentExtra[k] = v
                updated = true
            }
            if updated {
                existing.extraSlots = currentExtra
                map[key] = existing
                saveRecordedMap(map)
            }
            return
        }

        let gt = data[layout.greenTeaOffset] == 1
        let ngt = data[layout.notGreenTeaOffset] == 1
        var wapiVal: Bool? = nil
        if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: data) {
            wapiVal = (data[wIdx * 8] == 1)
        }
        let build = dict["CacheVersion"] as? String ?? ""
        map[key] = MGCacheRecordedFlags(
            layoutUUID: key,
            cacheVersion: build,
            greenTea: gt,
            notGreenTea: ngt,
            wapi: wapiVal,
            extraSlots: extraMap
        )
        saveRecordedMap(map)
    }

    func originalFlags(for layout: MGCacheDataLayout, savedOriginalDict: NSDictionary?) -> MGCacheRecordedFlags? {
        if let saved = savedOriginalDict,
           case .success(let savedData) = layout.validatePlist(saved) {
            let gt = savedData[layout.greenTeaOffset] == 1
            let ngt = savedData[layout.notGreenTeaOffset] == 1
            var wVal: Bool? = nil
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: savedData) {
                wVal = (savedData[wIdx * 8] == 1)
            }
            var extraMap: [String: Bool] = [:]
            for (fKey, fSlot) in layout.featureSlotIndices where layout.validateSingleBooleanSlot(fSlot, in: savedData) {
                extraMap[fKey] = (savedData[fSlot * 8] == 1)
            }
            let build = saved["CacheVersion"] as? String ?? ""
            return MGCacheRecordedFlags(
                layoutUUID: layout.uuid.uppercased(),
                cacheVersion: build,
                greenTea: gt,
                notGreenTea: ngt,
                wapi: wVal,
                extraSlots: extraMap
            )
        }
        return loadRecordedMap()[layout.uuid.uppercased()]
    }

    func originalSlotValue(forKey key: String, layout: MGCacheDataLayout, savedOriginalDict: NSDictionary?) -> Bool? {
        if let saved = savedOriginalDict,
           case .success(let savedData) = layout.validatePlist(saved),
           let slotIdx = layout.slotIndex(forKey: key),
           layout.validateSingleBooleanSlot(slotIdx, in: savedData) {
            return savedData[slotIdx * 8] == 1
        }
        return loadRecordedMap()[layout.uuid.uppercased()]?.extraSlots?[key]
    }

    private func loadRecordedMap() -> [String: MGCacheRecordedFlags] {
        guard let raw = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: MGCacheRecordedFlags].self, from: raw) else {
            return [:]
        }
        return decoded
    }

    private func saveRecordedMap(_ map: [String: MGCacheRecordedFlags]) {
        if let encoded = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }

    // MARK: - Strict Transition Audit & Diff Generation

    /// Ensures that ANY CacheData byte mutation ONLY touches dynamically resolved & validated Boolean offsets.
    /// Zero privilege bypasses: any unresolved layout or unrelated byte change is strictly blocked.
    func validateTransition(from beforeDict: NSDictionary, to afterDict: NSDictionary, using customLayout: MGCacheDataLayout? = nil) -> Result<Void, MGCacheResolutionError> {
        let beforeData = beforeDict["CacheData"] as? Data
        let afterData = afterDict["CacheData"] as? Data
        guard beforeData != afterData else {
            return .success(())
        }

        let layout: MGCacheDataLayout
        if let customLayout {
            layout = customLayout
        } else {
            switch libraryLayout() {
            case .failure(let err):
                return .failure(err)
            case .success(let resolved):
                layout = resolved
            }
        }

        guard case .success(let validBefore) = layout.validatePlist(beforeDict),
              case .success(let validAfter) = layout.validatePlist(afterDict),
              validBefore.count == validAfter.count else {
            switch layout.validatePlist(afterDict) {
            case .failure(let err):
                return .failure(err)
            case .success:
                if case .failure(let err2) = layout.validatePlist(beforeDict) {
                    return .failure(err2)
                }
                return .failure(.plistMismatch("Validasi CacheData sebelum dan sesudah modifikasi tidak lolos, penulisan ditolak."))
            }
        }

        let allowedOffsets = layout.permittedMutableOffsets
        if let wOff = layout.wapiOffset, validBefore[wOff] != validAfter[wOff] {
            if case .failure(let wErr) = layout.validatePlist(afterDict, checkWapiSlot: true) {
                return .failure(wErr)
            }
        }

        for (fKey, fSlot) in layout.featureSlotIndices {
            let fOff = fSlot * 8
            if validBefore[fOff] != validAfter[fOff] {
                guard layout.validateSingleBooleanSlot(fSlot, in: validBefore),
                      layout.validateSingleBooleanSlot(fSlot, in: validAfter) else {
                    return .failure(.slotInvalid("Slot fitur \(fSlot) (\(fKey)) tidak lolos verifikasi validitas boolean 8-byte, modifikasi ditolak!"))
                }
            }
        }

        for idx in validBefore.indices where validBefore[idx] != validAfter[idx] {
            guard allowedOffsets.contains(idx) else {
                return .failure(.unauthorizedByteMutation(String(format: "Terdeteksi perubahan byte cache tidak terkait yang tidak diotorisasi (offset 0x%X: 0x%02X -> 0x%02X), penulisan dihentikan paksa!", idx, validBefore[idx], validAfter[idx])))
            }
        }

        return .success(())
    }

    static func featureSlotMeta(forKey key: String) -> (id: String, label: String, trueHint: String, falseHint: String) {
        switch key {
        case MGCacheDataLayout.audioMixKey:
            return ("audio-mix", "Audio Mix Galeri dan Kamera", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.spatialAudioRecKey:
            return ("spatial-audio-rec", "Perekaman Audio Spasial (spatial-audio-recording)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.spatialFaceTimeAudioKey:
            return ("spatial-facetime-audio", "Audio Spasial FaceTime (spatial-facetime-audio)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.responsiveShutterKey:
            return ("responsive-shutter", "Jepretan Seketika Saat Tombol Rana Ditekan (ResponsiveShutter)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hypertensionNotifKey:
            return ("hypertension-notif", "Evaluasi Tren Hipertensi Kesehatan (HypertensionNotifications)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.appIntellKey:
            return ("ai-core-slot", "Slot Lapisan Bawah Apple Intelligence (GenerativeModelSystems)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.photosCleanUpKey:
            return ("photos-cleanup-slot", "Slot Lapisan Bawah Hapus Foto (Photos Clean Up)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.handwritingSynthKey:
            return ("handwriting-slot", "Slot Lapisan Bawah Sintesis Tulisan Tangan (Handwriting Synthesis)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.audioIntellKey:
            return ("audio-intell-slot", "Slot Lapisan Bawah Audio Intelligence iOS 27 (Audio Intelligence)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.personalTranslatorKey:
            return ("personal-translator-slot", "Slot Lapisan Bawah Terjemahan Real-time Pribadi (Personal Translator)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.islandKey:
            return ("dynamic-island-slot", "Slot Lapisan Bawah Dynamic Island (DynamicIsland)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.aodKey:
            return ("aod-slot", "Slot Lapisan Bawah Always-On Display (AOD)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.aoTimeKey:
            return ("aotime-slot", "Slot Waktu Always-On Display (AlwaysOnTime)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.aodVibrancyKey:
            return ("aod-vibrancy-slot", "Slot Saturasi Always-On Display (AODVibrancy)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.liquidGlassLowPowerKey:
            return ("liquid-glass-lp-slot", "Slot Liquid Glass Hemat Daya (LiquidGlassLowPower)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.chargeLimKey:
            return ("charge-limit-slot", "Slot Lapisan Bawah Batas Pengisian 80% (80ChargeLimit)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.bootChimeKey:
            return ("boot-chime-slot", "Slot Lapisan Bawah Suara Boot/Shutdown (BootChime)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.crashDetKey:
            return ("crash-det-slot", "Slot Lapisan Bawah Deteksi Kecelakaan (CollisionSOS)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.pwmKey:
            return ("pwm-slot", "Slot Lapisan Bawah Dimming PWM (PulseWidthMaximization)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.appPencilKey:
            return ("apple-pencil-slot", "Slot Lapisan Bawah Apple Pencil", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.camButtonKey:
            return ("cam-button-slot", "Slot Lapisan Bawah Tombol Kontrol Kamera (CameraButton)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.actButtonKey:
            return ("action-button-slot", "Slot Lapisan Bawah Tombol Aksi (RingerButton)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.tapToWakeKey:
            return ("tap-to-wake-slot", "Slot Lapisan Bawah Ketuk untuk Bangunkan (TapToWake)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.stageMgrKey:
            return ("stage-mgr-slot", "Slot Lapisan Bawah Stage Manager (EnhancedMultitasking)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.shutterRelaxationKey:
            return ("shutter-relax-slot", "[Uji] Slot Pengecualian Suara Rana Regional (RegionalCameraShutterRelaxation)", "true (0x01 · Diizinkan mute)", "false (0x00 · Suara rana wajib)")
        case MGCacheDataLayout.shutterKeyboardMutePreserveKey:
            return ("shutter-kb-mute-slot", "[Uji] Pertahankan Suara Rana Wajib Regional (KeyboardMutePreservesShutter)", "true (0x01 · Suara wajib dipertahankan)", "false (0x00 · Suara wajib dibuka)")
        case MGCacheDataLayout.shutterLegacyMutePreserveKey:
            return ("shutter-legacy-mute-slot", "[Uji] Model Lama Pertahankan Suara Rana Wajib (LegacyShutterPreserve)", "true (0x01 · Suara wajib dipertahankan)", "false (0x00 · Suara wajib dibuka)")
        case MGCacheDataLayout.concurrentHPLPMicsKey:
            return ("concurrent-mics-slot", "[Uji] Slot Mikrofon Ganda High-Low Power Bersamaan (ConcurrentHPLPMics)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.photosLocalLightKey:
            return ("photos-local-light-slot", "[Uji] Slot Redraw Cahaya Lokal Galeri (PhotosLocalLight)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.toneMappingKey:
            return ("tone-mapping-slot", "[Uji] Slot Pemetaan Nada Dinamis (ToneMapping)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hdrDeferredProcessingKey:
            return ("hdr-deferred-slot", "[Uji] Slot Render Delay HDR Mendalam (HDRDeferredProcessing)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.spatialOverCaptureKey:
            return ("spatial-overcapture-slot", "[Uji] Slot Penangkapan Spasial Ultra-Wide (SpatialOverCapture)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.stereoAudioRecKey:
            return ("stereo-audio-rec-slot", "[Uji] Slot Penangkapan Audio Video Stereo (StereoAudioRecording)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.p3VideoRecKey:
            return ("p3-video-rec-slot", "[Uji] Slot Perekaman Video Wide Color Gamut P3 (P3ColorspaceVideo)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.touchSensitiveCamControlKey:
            return ("touch-cam-control-slot", "[Uji] Slot Kontrol Kamera Sensitif Sentuh Kapasitif (TouchSensitiveCameraControl)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hardwareDetentsKey:
            return ("hw-detents-slot", "[Uji] Slot Damping Detent Taktil Fisik (HardwareDetents)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.cameraHapticsKey:
            return ("camera-haptics-slot", "[Uji] Slot Umpan Balik Haptik Halus Kamera (CameraHaptics)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.legacyBatteryInfoKey:
            return ("legacy-battery-info-slot", "[Uji] Slot Detail Kesehatan Baterai Model Lama (BatteryModelInfoLegacyHW)", "true (0x01 · Tampilkan siklus/tanggal)", "false (0x00 · Default Tersembunyi)")
        case MGCacheDataLayout.legacyDynamicEndOfChargeKey:
            return ("legacy-dyn-eoc-slot", "[Uji] Slot Pemutusan Pengisian Cerdas Model Lama (DynamicEndOfChargeLegacyHW)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.highLuminanceAODKey:
            return ("high-lum-aod-slot", "[Uji] Slot AOD Kecerahan Tinggi Outdoor (HighLuminanceAOD)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.aodFlipbookKey:
            return ("aod-flipbook-slot", "[Uji] Slot Frame Buffer Flipbook AOD Hemat Daya (AODFlipbook)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.carPlay2Key:
            return ("carplay2-slot", "[Uji] Slot CarPlay Ultra Multi-Layar Otomotif (CarPlay2)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.touchDelivery120HzKey:
            return ("touch-120hz-slot", "[Uji] Slot Pengiriman Touch 120Hz (TouchDelivery120Hz)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hearingAidEQKey:
            return ("hearingaid-eq-slot", "[Uji] Slot Ekualizer Alat Bantu Dengar Klinis (hearingaid-audio-equalization)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hearingAidLEKey:
            return ("hearingaid-le-slot", "[Uji] Slot Audio Low-Power Alat Bantu Dengar (hearingaid-low-energy-audio)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.hearingAidPowerRedKey:
            return ("hearingaid-pwr-slot", "[Uji] Slot Mode Pengurangan Daya Alat Bantu Dengar (hearingaid-power-reduction)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.breathingDisturbancesKey:
            return ("sleep-apnea-slot", "[Uji] Slot Deteksi Gangguan Pernapasan Tidur (BreathingDisturbances)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.usBloodOxygenKey:
            return ("us-blood-oxygen-slot", "[Uji] Slot Batasan Software SpO2 Versi AS (USLegallyCompliantBloodOxygen)", "true (0x01 · Dibatasi paten)", "false (0x00 · Batasan SpO2 dibuka)")
        case MGCacheDataLayout.workoutUltraKey:
            return ("workout-ultra-slot", "[Uji] Slot Mode Olahraga Ekstrem Outdoor (WorkoutUltraMode)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.timeInDaylightKey:
            return ("daylight-time-slot", "[Uji] Slot Pemantauan Durasi Paparan Sinar Matahari (TimeInDaylight)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.siriHubKey:
            return ("siri-hub-slot", "[Uji] Slot Routing Siri Hub On-Device (DeviceSupportsSiriHub)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.onDeviceSiriKey:
            return ("ondevice-siri-slot", "[Uji] Slot Kemampuan Siri Offline On-Device (OnDeviceSiriCapability)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        case MGCacheDataLayout.modelPruningKey:
            return ("model-pruning-slot", "[Uji] Slot Pruning Model Perintah On-Device (InstructionFollowingPruningModels)", "true (0x01 · Aktif)", "false (0x00 · Default Nonaktif)")
        default:
            return (key, "Slot Fitur Hardware (\(key))", "true (0x01)", "false (0x00)")
        }
    }

    func diffDetails(from beforeDict: NSDictionary, to afterDict: NSDictionary, using customLayout: MGCacheDataLayout? = nil) -> [MGCacheDataDiffDetail] {
        guard let beforeData = beforeDict["CacheData"] as? Data,
              let afterData = afterDict["CacheData"] as? Data,
              beforeData != afterData,
              beforeData.count == afterData.count else {
            return []
        }

        let resolvedLayout: MGCacheDataLayout? = customLayout ?? {
            if case .success(let l) = libraryLayout() { return l }
            return nil
        }()

        guard let layout = resolvedLayout,
              case .success = layout.validatePlist(beforeDict),
              case .success = layout.validatePlist(afterDict) else {
            return []
        }

        var details: [MGCacheDataDiffDetail] = []
        var describedOffsets = Set<Int>()

        let slots: [(id: String, label: String, key: String, slot: Int, trueHint: String, falseHint: String)] = {
            var arr: [(String, String, String, Int, String, String)] = [
                ("green-tea", "Penanda Batasan Versi Tiongkok (green-tea)", MGCacheDataLayout.greenTeaKey, layout.greenTeaIndex, "true (0x01 · Dibatasi)", "false (0x00 · Dibuka)"),
                ("not-green-tea", "Penanda Perangkat Non-Tiongkok (not-green-tea)", MGCacheDataLayout.notGreenTeaKey, layout.notGreenTeaIndex, "true (0x01 · Non-Tiongkok)", "false (0x00 · Default Tiongkok)")
            ]
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: beforeData) && layout.validateSingleBooleanSlot(wIdx, in: afterData) {
                arr.append(("wapi", "Penanda Tampilan WLAN (wapi)", MGCacheDataLayout.wapiKey, wIdx, "true (0x01 · WLAN)", "false (0x00 · Wi-Fi)"))
            }
            for fKey in layout.featureSlotIndices.keys.sorted() {
                if let fSlot = layout.featureSlotIndices[fKey],
                   layout.validateSingleBooleanSlot(fSlot, in: beforeData),
                   layout.validateSingleBooleanSlot(fSlot, in: afterData) {
                    let meta = Self.featureSlotMeta(forKey: fKey)
                    arr.append((meta.id, meta.label, fKey, fSlot, meta.trueHint, meta.falseHint))
                }
            }
            return arr
        }()

        for entry in slots {
            let off = entry.slot * 8
            if beforeData[off] != afterData[off] {
                describedOffsets.insert(off)
                details.append(
                    MGCacheDataDiffDetail(
                        id: "CacheData.\(entry.id)",
                        label: entry.label,
                        keyPath: String(format: "CacheData[0x%X] · slot %d (%@)", off, entry.slot, entry.key),
                        beforeText: beforeData[off] != 0 ? entry.trueHint : entry.falseHint,
                        afterText: afterData[off] != 0 ? entry.trueHint : entry.falseHint
                    )
                )
            }
        }

        let otherChangedCount = beforeData.indices.filter { !describedOffsets.contains($0) && beforeData[$0] != afterData[$0] }.count
        if otherChangedCount > 0 {
            details.append(
                MGCacheDataDiffDetail(
                    id: "CacheData.other",
                    label: "Offset Lain Cache Biner Lapisan Bawah (CacheData)",
                    keyPath: "CacheData",
                    beforeText: "<Data: \(beforeData.count) byte>",
                    afterText: "<Telah diubah \(otherChangedCount) byte>"
                )
            )
        }

        return details
    }

    func diagnosticReport(for dict: NSDictionary) -> String {
        switch resolveValidated(for: dict) {
        case .failure(let err):
            return "Status: ❌ Resolusi dinamis gagal (modifikasi ditolak dan dikunci)\nAlasan: \(err.localizedDescription)"
        case .success((let layout, let data)):
            let gtVal = data[layout.greenTeaOffset] == 1
            let ngtVal = data[layout.notGreenTeaOffset] == 1
            var lines: [String] = [
                "Status: ✅ Cocok secara presisi dengan pustaka sistem dan file cache perangkat",
                "CacheUUID: \(layout.uuid)",
                "Total slot: \(layout.slotCount) buah (total \(layout.byteCount) byte)",
                String(format: "green-tea: slot %d, offset 0x%X (bit valid 0x%X), nilai saat ini = %@",
                       layout.greenTeaIndex, layout.greenTeaOffset, layout.validityOffset(for: layout.greenTeaIndex), gtVal ? "true" : "false"),
                String(format: "not-green-tea: slot %d, offset 0x%X (bit valid 0x%X), nilai saat ini = %@",
                       layout.notGreenTeaIndex, layout.notGreenTeaOffset, layout.validityOffset(for: layout.notGreenTeaIndex), ngtVal ? "true" : "false")
            ]
            if let wIdx = layout.wapiIndex, layout.validateSingleBooleanSlot(wIdx, in: data) {
                let wOff = wIdx * 8
                let wVal = data[wOff] == 1
                lines.append(String(format: "wapi (WLAN/Wi-Fi): slot %d, offset 0x%X (bit valid 0x%X), nilai saat ini = %@",
                                    wIdx, wOff, layout.validityOffset(for: wIdx), wVal ? "true (WLAN)" : "false (Wi-Fi)"))
            } else {
                lines.append("wapi (WLAN/Wi-Fi): sistem saat ini tidak mengurai slot valid (dinonaktifkan secara terpisah)")
            }
            for fKey in MGCacheDataLayout.mediaHealthSlotKeys.sorted() {
                if let fSlot = layout.featureSlotIndices[fKey], layout.validateSingleBooleanSlot(fSlot, in: data) {
                    let meta = Self.featureSlotMeta(forKey: fKey)
                    let fVal = data[fSlot * 8] == 1
                    lines.append(String(format: "%@: slot %d, offset 0x%X, nilai saat ini = %@",
                                        meta.label, fSlot, fSlot * 8, fVal ? "true" : "false"))
                }
            }
            return lines.joined(separator: "\n")
        }
    }
}
