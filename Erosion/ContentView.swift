//
//  ContentView.swift
//  Erosion
//
//  Created by lunginspector on 8/14/26.
//

import SwiftUI


struct ContentView: View {
    @AppStorage("ogMachineName") var ogMachineName = ""
    @EnvironmentObject var mgr: ErosionManager
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    LogView()
                        .modifier(TerminalPlatter())
                } header: {
                    HeaderLabel("Log Aktivitas", symbol: "apple.terminal")
                } footer: {
                    Text("v\(AppInfo.appVersion) (Build \(AppInfo.appBuild)) · \(UIDevice.current.systemName) \(UIDevice.current.systemVersion) (\(buildNumber())) · \(machineName())")
                }
                
                Section {
                    Button("Muat Ulang Perangkat (Respring)") {
                        mgr.shouldRespring = true
                    }
                    Button {
                        promptGlobalFactoryRestore()
                    } label: {
                        Label("Pulihkan Parameter Pabrik Asli Sekali Klik", systemImage: "arrow.counterclockwise.shield.fill")
                    }
                } header: {
                    HeaderLabel("Aksi Cepat", symbol: "gearshape")
                } footer: {
                    Text("「Pulihkan Parameter Pabrik Asli Sekali Klik」 akan memverifikasi dan mengembalikan cadangan pabrik MobileGestalt secara in-place (termasuk redundansi vault lintas instalasi ulang sistem dan verifikasi SHA-256), sekaligus otomatis membersihkan teks bagian bawah layar kunci, plat nama aset, sisa pseudo-supervisi, dan cache keypad panggilan.")
                }
            }
            .navigationTitle("Erosion")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Pengaturan", systemImage: "gear")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                if ogMachineName.isEmpty {
                    ogMachineName = machineName()
                }
            }
        }
    }

    private func promptGlobalFactoryRestore() {
        Alertinator.shared.alert(
            title: "Konfirmasi pemulihan parameter pabrik asli sekali klik?",
            body: MGMsg.globalFactoryRestoreConfirm,
            actionLabel: "Konfirmasi Pemulihan Parameter Pabrik",
            action: {
                switch mgExecuteFactoryRestore(alsoResetConfigAndKeypad: true) {
                case .restoredSuccessfully(let details):
                    Haptic.shared.play(.soft)
                    Alertinator.shared.alert(
                        title: "Parameter pabrik asli berhasil dipulihkan!",
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
                            switch mgExecuteCleanCacheRebuild(alsoResetConfigAndKeypad: true) {
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
                    Alertinator.shared.alert(title: "Gagal memulihkan parameter pabrik asli!", body: reason)
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
