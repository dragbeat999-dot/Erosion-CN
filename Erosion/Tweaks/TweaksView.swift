//
//  TweaksView.swift
//  Erosion
//
//  Created by lunginspector on 8/26/26.
//

import SwiftUI

struct TweaksView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink("Kustomisasi Wallpaper Layar Kunci", destination: PosterBoardView())
                    NavigationLink("Perindah Keypad Panggilan", destination: KeypadView())
                } header: {
                    HeaderLabel("Kustomisasi Tampilan & Desktop", symbol: "paintbrush")
                }

                Section {
                    NavigationLink("Manajemen Data Aplikasi & Game", destination: AppDataBackupView())
                    NavigationLink("Pemindaian & Pembersihan Cache Kontainer", destination: CacheCleanerView())
                } header: {
                    HeaderLabel("Data Aplikasi & Pembersihan Ruang", symbol: "externaldrive.badge.checkmark")
                }
                
                Section {
                    if raveSupported() || weOnADebugBuild {
                        NavigationLink("Modifikasi MobileGestalt", destination: GestaltView())
                    }
                    NavigationLink("Konfigurasi & Pengawasan Sistem", destination: ConfigView())
                    NavigationLink("Penggantian File Sembarang", destination: OperationsView())
                } header: {
                    HeaderLabel("Lapisan Sistem", symbol: "gear")
                }

                Section {
                    NavigationLink("[Fitur Uji] Telemetri Kesehatan Baterai & Suhu", destination: PowerTelemetryView())
                    NavigationLink("[Fitur Uji] Analisis Crash & Pembunuhan Background oleh Jetsam", destination: CrashDiagnosticsView())
                    NavigationLink("[Fitur Uji] Aturan Aliran App Group & Ekspor Bookmark", destination: AppGroupHubView())
                    NavigationLink("[Fitur Uji] Ekstraksi Voice Memo & Pemeriksaan Model AI", destination: VoiceMemosAIView())
                } header: {
                    HeaderLabel("Fitur Eksperimental Lintas Kontainer (Fitur Uji)", symbol: "flask")
                } footer: {
                    Text("Modul eksperimental di atas dan 'Mesin Pemetaan Kontainer Cepat CSStore2' di halaman pengaturan adalah fitur uji v0.8.0: semua database sistem dibaca menggunakan snapshot read-only tanpa lock dari APFS clonefile(), tanpa memodifikasi file daemon asli.")
                }
            }
            .navigationTitle("Modifikasi Fitur")
        }
    }
}
