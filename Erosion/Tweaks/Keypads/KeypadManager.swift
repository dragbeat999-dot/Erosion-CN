//
//  KeypadManager.swift
//  Erosion
//
//  Created by lunginspector on 8/27/26.
//

import Combine
import Foundation
import UIKit
import ZIPFoundation

// i hate you, apple incorporated.
// with love, lunginspector. august 28th, 2026.
enum KeypadID: String, CaseIterable {
    case one, two, three, four, five, six, seven, eight, nine, star, zero, pound
    
    var keyFragment: String {
        switch self {
        case .one: return "-1-"
        case .two: return "-2-A B C"
        case .three: return "-3-D E F"
        case .four: return "-4-G H I"
        case .five: return "-5-J K L"
        case .six: return "-6-M N O"
        case .seven: return "-7-P Q R S"
        case .eight: return "-8-T U V"
        case .nine: return "-9-W X Y Z"
        case .star: return "-*-"
        case .zero: return "-0-+"
        case .pound: return "-#-"
        }
    }
    
    var fileNames: [String] {
        fileNames(withPrefix: kp.getFileRegCode())
    }
    
    func fileNames(withPrefix prefix: String) -> [String] {
        let files = ["--mask.png", "--white.png", "-hi-mask.png", "-hi-white.png", "--white-bold.png", "--mask-bold.png"]
        return files.map { prefix + keyFragment + $0 }
    }
    
    func getAccentedFileName() -> String {
        let appearance = UIScreen.main.traitCollection.userInterfaceStyle
        switch appearance {
        case .light: return self.fileNames[0]
        case .dark: return self.fileNames[1]
        default: return self.fileNames[0]
        }
    }
}

enum KPSize: Int, CaseIterable {
    case defSize, small, medium, large, custom
    
    var float: CGFloat {
        switch self {
        case .small: return CGFloat(150)
        case .medium: return CGFloat(205)
        case .large: return CGFloat(225)
        default: return CGFloat(0)
        }
    }
    
    var label: String {
        switch self {
        case .defSize: return "Default"
        case .small: return "Kecil"
        case .medium: return "Sedang"
        case .large: return "Besar"
        case .custom: return "Kustom"
        }
    }
}

enum KPSizeLimits {
    static let min = CGFloat(50)
    static let max = CGFloat(2500)
}

struct KeypadItem: Identifiable, Equatable {
    let id = UUID()
    var kpID: KeypadID
    var imgData = Data()
    var ogImgData = Data()
}

let emptyKeypadArray = [
    KeypadItem(kpID: KeypadID.one), KeypadItem(kpID: KeypadID.two), KeypadItem(kpID: KeypadID.three), KeypadItem(kpID: KeypadID.four), KeypadItem(kpID: KeypadID.five), KeypadItem(kpID: KeypadID.six), KeypadItem(kpID: KeypadID.seven), KeypadItem(kpID: KeypadID.eight), KeypadItem(kpID: KeypadID.nine), KeypadItem(kpID: KeypadID.star), KeypadItem(kpID: KeypadID.zero), KeypadItem(kpID: KeypadID.pound)
]

enum KPMsg {
    static let resetWarn = "Setelah diatur ulang, pola tombol yang sedang diedit serta tema dial yang sudah aktif di aplikasi \"Telepon\" akan hilang."
    static let applyComp = "Agar tombol dial berlaku, buka aplikasi \"Telepon\" dan ganti mode terang/gelap hingga tombol kustom muncul, atau langsung restart perangkat. Jangan pernah menutup paksa aplikasi \"Telepon\" dengan menggeser ke atas di latar belakang!"
}

let kp = KeypadManager()
final class KeypadManager: ObservableObject {
    static let shared = KeypadManager()
    private static let savedRegCodeKey = "kpDetectedFileRegCode"
    
    @Published var mpKeypad = [KeypadItem]()
    
    private var mpContainerPath = {
        return UserDefaults.standard.value(forKey: "mpContainerPath") as? String ?? ""
    }
    
    init() {
        if mpKeypad.isEmpty {
            mpKeypad = emptyKeypadArray
        }
    }
    
    // fun...
    func getFileRegCode() -> String {
        let base = mpContainerPath()
        if !base.isEmpty {
            let tpURL = URL(fileURLWithPath: base).appendingPathComponent("Library/Caches/TelephonyUI-10")
            if let tpURLs = try? fm.contentsOfDirectory(at: tpURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for fileURL in tpURLs where fileURL.pathExtension.lowercased() == "png" {
                    let split = fileURL.lastPathComponent.split(separator: "-").map { String($0) }
                    if let first = split.first, !first.isEmpty, first != "other" {
                        UserDefaults.standard.set(first, forKey: Self.savedRegCodeKey)
                        return first
                    }
                }
            }
        }
        if let cached = UserDefaults.standard.string(forKey: Self.savedRegCodeKey), !cached.isEmpty, cached != "other" {
            return cached
        }
        return "other"
    }
    
    func updateKeypadItem(forID id: KeypadID, withData data: Data, ogData: Data? = nil) {
        if let index = mpKeypad.firstIndex(where: { $0.kpID == id }) {
            mpKeypad[index].imgData = data
            if let data = ogData {
                mpKeypad[index].ogImgData = data
            }
        }
    }
    
    private func isValidPNGData(_ data: Data) -> Bool {
        let pngSig: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        guard data.count > 64 else { return false }
        return Array(data.prefix(8)) == pngSig && UIImage(data: data) != nil
    }

    func applyKeypadItems() -> Bool {
        let base = mpContainerPath()
        guard !base.isEmpty else { return false }
        guard wq.grantAccess(path: base).0 else { return false }
        let tpURL = URL(fileURLWithPath: base).appendingPathComponent("Library/Caches/TelephonyUI-10")
        do {
            try fm.createDirectory(at: tpURL, withIntermediateDirectories: true)
        } catch {
            print("(kp) gagal membuat direktori TelephonyUI-10: \(error.localizedDescription)")
            return false
        }
        _ = wq.grantAccess(path: tpURL.path)
        var failed = 0
        var appliedAny = false
        let targetPrefix = getFileRegCode()
        for item in mpKeypad {
            // Skip untouched/empty keypad buttons instead of writing 0-byte PNGs (SEC-M4-06)
            guard !item.imgData.isEmpty else { continue }
            guard isValidPNGData(item.imgData) else {
                print("(kp) menolak data PNG tidak valid/rusak untuk keypad \(item.kpID)")
                failed += 1
                continue
            }
            let files = item.kpID.fileNames(withPrefix: targetPrefix)
            for fileName in files {
                let finalURL = tpURL.appendingPathComponent(fileName)
                do {
                    if fm.fileExists(atPath: finalURL.path) {
                        let res = writeFileAtomically(item.imgData, to: finalURL)
                        if !res.0 { throw res.1 }
                    } else {
                        try item.imgData.write(to: finalURL, options: .atomic)
                    }
                    appliedAny = true
                } catch {
                    print("(kp) gagal menulis data gambar: \(error.localizedDescription)")
                    failed += 1
                }
            }
        }
        return failed == 0 && appliedAny
    }
    
    func resetKeypadItems() -> Bool {
        do {
            var base = mpContainerPath()
            if base.isEmpty {
                base = fsHandlers.getContainerPath(forMatch: "com.apple.mobilephone")
                if !base.isEmpty {
                    UserDefaults.standard.set(base, forKey: "mpContainerPath")
                }
            }
            guard !base.isEmpty, wq.grantAccess(path: base).0 else { return false }
            let filesURL = URL(fileURLWithPath: base).appendingPathComponent("Library/Caches/TelephonyUI-10")
            let targetPrefix = getFileRegCode()
            var targetNames = Set<String>()
            for item in mpKeypad {
                for fn in item.kpID.fileNames(withPrefix: targetPrefix) { targetNames.insert(fn) }
                for fn in item.kpID.fileNames(withPrefix: "other") { targetNames.insert(fn) }
            }
            if fm.fileExists(atPath: filesURL.path) {
                _ = wq.grantAccess(path: filesURL.path)
                let files = try fm.contentsOfDirectory(at: filesURL, includingPropertiesForKeys: [])
                for fileURL in files where targetNames.contains(fileURL.lastPathComponent) {
                    try fm.removeItem(at: fileURL)
                }
            }
            clearKeypads()
            return true
        } catch {
            print("(kp) gagal mengatur ulang item keypad: \(error.localizedDescription)")
        }
        return false
    }
    
    func clearKeypads() {
        for keypad in mpKeypad {
            if let index = mpKeypad.firstIndex(where: { $0.id == keypad.id }) {
                mpKeypad[index].ogImgData = Data()
                mpKeypad[index].imgData = Data()
            }
        }
    }
    
    func resizeAndRet(withData data: Data, newSize: CGFloat = CGFloat(0), customSize: CGSize? = nil, shallCircle: Bool = false, isDefault: Bool = false) -> Data {
        if let image = UIImage(data: data) {
            var width = isDefault ? image.size.width : customSize?.width ?? newSize
            var height = isDefault ? image.size.height: customSize?.height ?? newSize
            width = min(max(width, KPSizeLimits.min), KPSizeLimits.max)
            height = min(max(height, KPSizeLimits.min), KPSizeLimits.max)
            let resized = image.resized(to: CGSize(width: width, height: height), shouldCircle: shallCircle)
            if let newData = resized.pngData() {
                return newData
            }
        }
        return data
    }
    
    func getCurrentKeypads(size: KPSize = KPSize.defSize, custW: Int = 0, custH: Int = 0, saveOgData: Bool = false) {
        do {
            let filesURL = URL(fileURLWithPath: mpContainerPath()).appendingPathComponent("Library/Caches/TelephonyUI-10")
            for kpId in KeypadID.allCases {
                let fileName = kpId.getAccentedFileName()
                let url = filesURL.appendingPathComponent(fileName)
                let data = try Data(contentsOf: url)
                let imgData = {
                    switch size {
                    case .defSize: return resizeAndRet(withData: data, isDefault: true)
                    case .custom: return resizeAndRet(withData: data, customSize: CGSize(width: custW, height: custH))
                    default: return resizeAndRet(withData: data, newSize: size.float)
                    }
                }()
                if saveOgData {
                    updateKeypadItem(forID: kpId, withData: imgData, ogData: imgData)
                } else {
                    updateKeypadItem(forID: kpId, withData: imgData)
                }
            }
        } catch {
            // keypads could've been reset so nothing to log here, logs are just gonna spit out nonsense
        }
    }
    
    func changeSizeOfKeypads(size: KPSize = KPSize.defSize, custW: Int = 0, custH: Int = 0) {
        for kpItem in mpKeypad {
            let data = kpItem.ogImgData
            let imgData = {
                switch size {
                case .defSize: return resizeAndRet(withData: data, isDefault: true)
                case .custom: return resizeAndRet(withData: data, customSize: CGSize(width: custW, height: custH))
                default: return resizeAndRet(withData: data, newSize: size.float)
                }
            }()
            updateKeypadItem(forID: kpItem.kpID, withData: imgData)
        }
    }
    
    func maskKeysIntoCircle(size: KPSize = KPSize.defSize, custW: Int = 0, custH: Int = 0) {
        for kpItem in mpKeypad {
            let data = kpItem.ogImgData
            let imgData = {
                switch size {
                case .defSize: return resizeAndRet(withData: data, shallCircle: true, isDefault: true)
                case .custom: return resizeAndRet(withData: data, customSize: CGSize(width: custW, height: custH), shallCircle: true)
                default: return resizeAndRet(withData: data, newSize: size.float, shallCircle: true)
                }
            }()
            updateKeypadItem(forID: kpItem.kpID, withData: imgData)
        }
    }
    
    // by far the most annoying piece of swift i've ever had to write. but, it works how it should, so i'm happy.
    // -lunginspector, 9/11/26
    func importTheme(fromURL fileURL: URL) -> Bool {
        let tempURL = URL.temporaryDirectory.appendingPathComponent("ImportedKeypad_\(UUID().uuidString)")
        defer { try? fm.removeItem(at: tempURL) }
        do {
            guard let archive = try? Archive(url: fileURL, accessMode: .read) else {
                throw "Tidak dapat membaca arsip tema dial!"
            }
            let destStd = tempURL.standardizedFileURL
            let destPrefix = destStd.path.hasSuffix("/") ? destStd.path : destStd.path + "/"
            for entry in archive {
                let entryPath = entry.path
                if entryPath.hasPrefix("/") || entryPath.split(separator: "/").contains("..") || entryPath.split(separator: "\\").contains("..") {
                    throw "Terdeteksi paket tema berisi entri path traversal ilegal (\(entryPath)), impor ditolak!"
                }
                let resolvedPath = destStd.appendingPathComponent(entryPath).standardizedFileURL.path
                if resolvedPath != destStd.path && !resolvedPath.hasPrefix(destPrefix) {
                    throw "Terdeteksi entri paket tema melewati batas (\(entryPath)), impor ditolak!"
                }
            }
            var filesURL = tempURL
            try fm.createDirectory(at: filesURL, withIntermediateDirectories: true)
            try fm.unzipItem(at: fileURL, to: filesURL)
            let dirURLs = try fm.contentsOfDirectory(at: filesURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).filter { $0.lastPathComponent != "__MACOSX" }
            if dirURLs.count < 1 {
                throw "Tidak ada file yang ditemukan di dalam folder hasil ekstraksi!"
            } else if dirURLs.count == 1 {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: dirURLs[0].path, isDirectory: &isDir), isDir.boolValue {
                    filesURL = dirURLs[0]
                }
            } else if let index = dirURLs.firstIndex(where: { $0.lastPathComponent == "TelephonyUI-8" || $0.lastPathComponent == "TelephonyUI-9" || $0.lastPathComponent == "TelephonyUI-10" }) {
                filesURL = dirURLs[index]
            } else if !dirURLs.contains(where: { $0.pathExtension.lowercased() == "png" }) {
                throw "Tidak ada folder TelephonyUI yang ditemukan di dalam folder hasil ekstraksi!"
            }
            // once extracted check each file for a match with the right image (excluding -hi- highlight images)
            let fileURLs = try fm.contentsOfDirectory(at: filesURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                .filter { !$0.lastPathComponent.contains("-hi-") }
            let preferredAppr = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? "white" : "mask"
            
            func matchFiles(acceptedAppearances: Set<String>) throws -> Int {
                var count = 0
                var matchedIDs = Set<KeypadID>()
                for itemURL in fileURLs {
                    let split = itemURL.lastPathComponent.split(separator: "-").map { String($0) }
                    let apprName: String = {
                        if split.indices.contains(3) {
                            let appearance = String(split[3].split(separator: ".")[0])
                            if acceptedAppearances.contains(appearance) {
                                return split[3]
                            }
                        }
                        if split.indices.contains(2) {
                            let appearance = String(split[2].split(separator: ".")[0])
                            if acceptedAppearances.contains(appearance) {
                                return split[2]
                            }
                        }
                        return ""
                    }()
                    guard !apprName.isEmpty, split.indices.contains(1) else { continue }
                    let keyNum = split[1]
                    if let id = KeypadID.allCases.first(where: { $0.fileNames.contains { $0.contains("-\(keyNum)-") && $0.contains(apprName) } }),
                       !matchedIDs.contains(id) {
                        let data = try Data(contentsOf: itemURL)
                        updateKeypadItem(forID: id, withData: data, ogData: data)
                        matchedIDs.insert(id)
                        count += 1
                    }
                }
                return count
            }
            
            var replaceCount = try matchFiles(acceptedAppearances: [preferredAppr])
            if replaceCount < 1 {
                replaceCount = try matchFiles(acceptedAppearances: ["mask", "white"])
            }
            if replaceCount < 1 {
                throw "File berhasil diekstrak, tetapi tidak ada tombol yang ditemukan?"
            }
            print("(kp) berhasil mengimpor tema! fileName: \(fileURL.lastPathComponent), tombol diimpor: \(replaceCount)")
            return true
        } catch {
            print("(kp) gagal mengimpor tema: \(error.localizedDescription)")
        }
        return false
    }
}

extension UIImage {
    func resized(to size: CGSize, scale: CGFloat = 1.0, shouldCircle: Bool = false) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ctx = context.cgContext

            if shouldCircle {
                ctx.addEllipse(in: CGRect(origin: .zero, size: size))
                ctx.clip()

                let fillScale = max(size.width / self.size.width, size.height / self.size.height)
                let drawSize = CGSize(width: self.size.width * fillScale, height: self.size.height * fillScale)
                let origin = CGPoint(
                    x: (size.width - drawSize.width) / 2,
                    y: (size.height - drawSize.height) / 2
                )
                draw(in: CGRect(origin: origin, size: drawSize))
            } else {
                draw(in: CGRect(origin: .zero, size: size))
            }
        }
    }
}
