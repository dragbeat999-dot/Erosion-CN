//
//  KeypadView.swift
//  Erosion
//
//  Created by lunginspector on 8/28/26.
//

import SwiftUI

import PhotosUI

struct KeypadView: View {
    @StateObject private var kpMgr = KeypadManager.shared
    @AppStorage("mpContainerPath") private var mpContainerPath = ""
    @State private var isReady = false
    @State private var hasAccess = false
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
    @State private var size: KPSize = KPSize.defSize
    @State private var showSizeAlert = false
    @State private var custW = 0
    @State private var custH = 0
    @State private var showFileImporter = false
    
    var body: some View {
        VStack {
            if !isReady {
                VStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(1.25)
                    Text("Sedang menemukan jalur container sistem...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: columns, alignment: .center, spacing: 16) {
                    ForEach($kpMgr.mpKeypad) { $item in
                        KeyItem(size: $size, kpID: item.kpID, imgData: $item.imgData)
                            .environmentObject(kpMgr)
                    }
                }
                .safeAreaInset(edge: .top) {
                    VStack(spacing: 2) {
                        Text("Ukuran Tombol")
                        Picker("", selection: $size) {
                            ForEach(KPSize.allCases, id: \.self) { kpSize in
                                Text(kpSize.label + (kpSize == .custom ? " (\(custW)x\(custH))" : "")).tag(kpSize)
                            }
                        }
                        .alert("Masukkan ukuran tombol kustom (piksel)", isPresented: $showSizeAlert) {
                            TextField("Lebar", value: $custW, format: .number)
                                .keyboardType(.numberPad)
                            TextField("Tinggi", value: $custH, format: .number)
                                .keyboardType(.numberPad)
                            Button("Batal", role: .cancel) {
                                size = .defSize
                            }
                            Button("Terapkan") {
                                kpMgr.changeSizeOfKeypads(size: size, custW: custW, custH: custH)
                            }
                        }
                        .onChange(of: size) { _, newSize in
                            if newSize != KPSize.custom {
                                kpMgr.changeSizeOfKeypads(size: newSize)
                            } else {
                                showSizeAlert.toggle()
                            }
                        }
                    }
                    .padding(6)
                    .background(Color(.systemBackground), in: .rect(cornerRadius: cornerRad.component))
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        let res = kpMgr.applyKeypadItems()
                        if res {
                            Alertinator.shared.alert(title: "Tema keypad dial berhasil diterapkan!", body: KPMsg.applyComp, actionLabel: "Buka Telepon", action: {
                                openApp(withBID: SysBID.phone)
                            })
                            Haptic.shared.play(.soft)
                        } else {
                            Alertinator.shared.alert(title: "Gagal menerapkan tema keypad dial!", body: AppMsg.opFailed)
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(KeypadButtonStyle(isConfirm: true))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
                    .disabled(!hasAccess)
                }
            }
        }
        .navigationTitle(isPad() ? "" : "Kustomisasi Keypad Dial")
        .frame(maxWidth: 325)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        kpMgr.maskKeysIntoCircle(size: size, custW: custW, custH: custH)
                    } label: {
                        Label("Potong Menjadi Tombol Bulat", systemImage: "circle")
                    }
                    Button {
                        size = .defSize
                        kpMgr.getCurrentKeypads()
                    } label: {
                        Label("Baca Tombol Saat Ini", systemImage: "externaldrive")
                    }
                    .disabled(!hasAccess)
                    Button {
                        setupPhoneContainer(forceRefresh: true)
                    } label: {
                        Label("Ambil Ulang Jalur Container Telepon", systemImage: "arrow.clockwise")
                    }
                    Button {
                        openApp(withBID: SysBID.phone)
                    } label: {
                        Label("Buka Aplikasi Telepon", systemImage: "arrow.up.right.square")
                    }
                    Divider()
                    Button {
                        size = .defSize
                        kpMgr.clearKeypads()
                    } label: {
                        Label("Kosongkan Editan Saat Ini", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        Alertinator.shared.alert(title: "Yakin ingin mengatur ulang tombol dial?", body: KPMsg.resetWarn, actionLabel: "Konfirmasi", action: {
                            let res = kpMgr.resetKeypadItems()
                            if res {
                                kpMgr.mpKeypad = emptyKeypadArray
                                kpMgr.getCurrentKeypads()
                                Alertinator.shared.alert(title: "Keypad dial berhasil dipulihkan ke default!", body: KPMsg.applyComp)
                            } else {
                                Alertinator.shared.alert(title: "Gagal mengatur ulang keypad dial!", body: AppMsg.opFailed)
                            }
                        })
                    } label: {
                        Label("Pulihkan Default Sistem", systemImage: "trash")
                    }
                    .disabled(!hasAccess)
                } label: {
                    Label("Menu", systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                }
                .disabled(!isReady)
            }
            ToolbarSpacer(placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button("Impor Tema") {
                    showFileImporter = true
                }
                .disabled(!isReady || !hasAccess)
            }
        }
        .onAppear {
            setupPhoneContainer(forceRefresh: false)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            handleImport(result)
        }
    }
    
    private func setupPhoneContainer(forceRefresh: Bool) {
        if forceRefresh {
            isReady = false
        }
        DispatchQueue.global(qos: .userInitiated).async {
            var targetPath = forceRefresh ? "" : mpContainerPath
            var accessOK = false
            if !targetPath.isEmpty {
                let grant = wq.grantAccess(path: targetPath)
                if grant.0 && fm.fileExists(atPath: targetPath) {
                    accessOK = true
                } else {
                    targetPath = ""
                }
            }
            if targetPath.isEmpty {
                let fetched = fsHandlers.getContainerPath(forMatch: "com.apple.mobilephone")
                if !fetched.isEmpty {
                    targetPath = fetched
                    let grant = wq.grantAccess(path: targetPath)
                    accessOK = grant.0 && fm.fileExists(atPath: targetPath)
                }
            }
            if accessOK {
                let cachesPath = "\(targetPath)/Library/Caches"
                if fm.fileExists(atPath: cachesPath) {
                    _ = wq.grantAccess(path: cachesPath)
                }
                let tpPath = "\(targetPath)/Library/Caches/TelephonyUI-10"
                if fm.fileExists(atPath: tpPath) {
                    _ = wq.grantAccess(path: tpPath)
                }
            }
            DispatchQueue.main.async {
                if !targetPath.isEmpty {
                    mpContainerPath = targetPath
                }
                hasAccess = accessOK
                if accessOK {
                    kpMgr.getCurrentKeypads(size: size, saveOgData: true)
                } else {
                    Alertinator.shared.alert(title: "Tidak dapat mengakses container aplikasi Telepon!", body: "Gagal menemukan atau memberi izin pada container com.apple.mobilephone, silakan buka aplikasi \"Telepon\" sistem terlebih dahulu, atau klik \"Ambil Ulang Jalur Container Telepon\" pada menu di kanan atas.")
                }
                isReady = true
            }
        }
    }
    
    private struct KeyItem: View {
        @EnvironmentObject private var kpMgr: KeypadManager
        @Binding var size: KPSize
        @State var kpID: KeypadID
        @Binding var imgData: Data
        @State private var showPicker = false
        
        var body: some View {
            Button {
                showPicker = true
            } label: {
                if let img = UIImage(data: imgData) {
                    let denoVal: Float = isPad() ? 2.1 : 3.0
                    Image(uiImage: img)
                        .resizable()
                        .frame(width: CGFloat(Float(img.size.width)/denoVal), height: CGFloat(Float(img.size.height)/denoVal))
                        .background {
                            Circle()
                                .fill(Color.clear)
                                .glassEffect(.clear, in: .circle)
                                .frame(width: 78, height: 78)
                        }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 24))
                        .frame(width: 78, height: 78)
                        .foregroundStyle(Color(.label))
                        .fontWeight(.medium)
                        .glassEffect(.clear.interactive(), in: .circle)
                }
            }
            .frame(width: 80, height: 80)
            .sheet(isPresented: $showPicker) {
                ImagePickerView() { data in
                    imgData = data
                    guard let img = UIImage(data: imgData) else { return }
                    let imgData = {
                        switch size {
                        case .defSize: return kpMgr.resizeAndRet(withData: data, isDefault: true)
                        case .custom: return kpMgr.resizeAndRet(withData: data, customSize: CGSize(width: Int(img.size.width), height: Int(img.size.height)))
                        default: return kpMgr.resizeAndRet(withData: data, newSize: size.float)
                        }
                    }()
                    kpMgr.updateKeypadItem(forID: kpID, withData: imgData, ogData: imgData)
                }
            }
        }
    }
    
    // MARK: handle import
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let fileURL):
            do {
                let stopAccess = fileURL.startAccessingSecurityScopedResource()
                defer {
                    if stopAccess {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                let res = kpMgr.importTheme(fromURL: fileURL)
                if res {
                    Haptic.shared.play(.soft)
                } else {
                    throw "gagal mengimpor tema!"
                }
            } catch {
                print("(kp) gagal mengimpor tema: \(error.localizedDescription)")
                Alertinator.shared.alert(title: "Gagal mengimpor tema!", body: AppMsg.opFailed)
            }
        case .failure(let error):
            print("(kp) gagal mengimpor file: \(error.localizedDescription)")
            Alertinator.shared.alert(title: "Gagal mengimpor tema!", body: "\(error.localizedDescription)")
        }
    }
    
}

// MARK: UI
struct KeypadButtonStyle: ButtonStyle {
    var isConfirm = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 24))
            .frame(width: 75, height: 75)
            .foregroundStyle(Color(.label))
            .fontWeight(.medium)
            .glassEffect(.clear.tint(isConfirm ? Color.accentColor : Color.clear).interactive(), in: .circle)
    }
}
