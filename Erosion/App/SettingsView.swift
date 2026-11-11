//
//  SettingsView.swift
//  Erosion
//
//  Created by lunginspector on 8/20/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("autoRespring") var autoRespring = false
    @AppStorage(CSStoreEngine.fastScanDefaultsKey) var useCSStoreFastScan = true
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Muat ulang otomatis setelah menerapkan modifikasi", isOn: $autoRespring)
                    PlainToggle(
                        "[Fitur Uji] Mesin Pemetaan Container Kilat CSStore2",
                        subtitle: "Mengurai aplikasi dan grup bersama seluruh perangkat dalam hitungan milidetik melalui pustaka biner LaunchServices, menggantikan penelusuran Inode yang lambat",
                        infoType: .info,
                        infoTitle: "Mesin Container Kilat CSStore2 (Fitur Uji)",
                        infoMessage: "Mengurai pustaka biner com.apple.LaunchServices-*.csstore (magic number bdsl) secara read-only dari InternalDaemon, mampu memetakan container seluruh aplikasi, plugin ekstensi, dan AppGroup dalam hitungan puluhan milidetik beserta nama aplikasi; jika pembacaan gagal akan otomatis mundur mulus ke penelusuran pathleak tradisional.",
                        isOn: $useCSStoreFastScan
                    )
                    if useCSStoreFastScan {
                        Button("Segarkan Cache Peta Container CSStore2") {
                            CSStoreEngine.shared.invalidate()
                            let summary = CSStoreEngine.shared.summaryText()
                            Alertinator.shared.alert(title: "Status Peta CSStore2", body: summary)
                        }
                    }
                } header: {
                    HeaderLabel("Pengaturan Aplikasi", symbol: "gearshape")
                } footer: {
                    Text("Memicu muat ulang perangkat (Respring) secara otomatis setelah modifikasi fitur berhasil diterapkan. Fitur yang ditandai [Fitur Uji] dapat dinonaktifkan dan dikembalikan di sini kapan saja jika terjadi anomali kompatibilitas sistem.")
                }
                
                Section {
                    AppInfoCell(build: build)
                } header: {
                    HeaderLabel("Tentang", symbol: "info.circle")
                } footer: {
                    Text("Dibuat dengan penuh dedikasi oleh tim [jailbreak.party](https://jailbreak.party) · Versi lokalisasi Bahasa Indonesia")
                }
                
                Section {
                    LinkCreditCell(image: Image("lunginspector"), name: "lunginspector", description: "Pengembang utama dan pemelihara proyek", url: "https://github.com/lunginspector")
                    LinkCreditCell(image: Image("forcequit"), name: "forcequit", description: "Penulis celah pelarian sandbox worse_query", url: "https://github.com/forcequitOS")
                    LinkCreditCell(image: Image("0xjohnny"), name: "0xjohnny", description: "Penulis celah pelarian sandbox worse_query", url: "https://github.com/0xjohnnydev")
                    LinkCreditCell(image: Image("skadz108"), name: "Skadz", description: "Integrasi celah, fungsi inti backend, dan pemeliharaan proyek", url: "https://github.com/skadz108")
                    LinkCreditCell(image: Image("rooootdev"), name: "rooootdev", description: "Dukungan berbagai komponen backend", url: "https://github.com/rooootdev")
                    LinkCreditCell(image: Image("neonmodder123"), name: "neonmodder123", description: "Penulis solusi respring tanpa jailbreak via WebView", url: "https://github.com/neonmodder123")
                } header: {
                    HeaderLabel("Penulis Proyek Hulu (jailbreak.party)", symbol: "star")
                }

                Section {
                    LinkCreditCell(name: "huamidev — GestaltX", description: "Referensi desain unggul: parsing offset cache dinamis pustaka sistem, pratinjau perbandingan perubahan, verifikasi pasca-tulis, dan deteksi App Group yang ditandatangani ulang", url: "https://github.com/huamidev/GestaltX")
                    LinkCreditCell(name: "kolbicz — WQFiles", description: "Referensi desain arsitektur pemetaan container cepat dan telemetri read-only lintas container LaunchServices CSStore2 (bdsl)", url: "https://github.com/kolbicz/WQFiles")
                    LinkCreditCell(name: "KirbySD", description: "Berbagi ide penelitian offset slot boolean MobileGestalt CacheData", url: "https://www.v2ex.com/t/1246550")
                    LinkCreditCell(name: "PoomSmart — MGKeys", description: "Pemeliharaan dan pengorganisasian tabel pemetaan key-value terobfuskasi MobileGestalt", url: "https://github.com/PoomSmart/MGKeys")
                } header: {
                    HeaderLabel("Ucapan Terima Kasih Khusus dan Referensi Fitur", symbol: "heart")
                }
            }
            .navigationTitle("Pengaturan")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        ToolbarLabel("Tutup", symbol: "xmark")
                    }
                }
            }
        }
    }
}
