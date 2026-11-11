//
//  GestaltStore.swift
//  Erosion
//
//  Created by lunginspector on 8/19/26.
//

import SwiftUI

import Combine

enum MGURL {
    static let fsGestaltURL = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
    static let savedGestaltURL = URL.documentsDirectory.appendingPathComponent("OriginalGestalt.plist")
    static let savedGestaltSHA256URL = URL.documentsDirectory.appendingPathComponent("OriginalGestalt.sha256")
    static let preApplyGestaltURL = URL.documentsDirectory.appendingPathComponent("PreApplyGestalt.plist")
    // System-level vault inside mobilegestaltcache Caches: survives sideload app uninstall/reinstall while excluded from iCloud/Finder migration
    static let systemVaultGestaltURL = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/.erosion_factory_vault.plist")
    static let systemVaultSHA256URL = URL(fileURLWithPath: "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/.erosion_factory_vault.sha256")
}

enum MGRegionUnlockMode: String, CaseIterable, Identifiable {
    case fullUS = "full_us"
    case regionCodeOnly = "ll_only"

    static let defaultsKey = "mgRegionUnlockMode"
    var id: String { rawValue }
}

enum MGMsg {
    // warnings
    static let region = "Setelah diaktifkan, secara default wilayah penjualan akan diubah menjadi versi AS lengkap (LL + LL/A) dan memetakan model regulasi AS yang sesuai (Axxxx); Anda juga dapat beralih ke sub-opsi di bawah ke \"Hanya ubah kode wilayah LL (pertahankan akhiran CH/A dan kompatibilitas dual-SIM)\". Patuhi hukum dan peraturan setempat dan tanggung sendiri risikonya."
    static let regionModeInfo = "【Penjelasan Rinci Mode Modifikasi Wilayah】\n\n1. Versi AS Lengkap LL + LL/A (default):\nSekaligus mengubah kode wilayah menjadi LL, wilayah penjualan sistem menjadi LL/A, dan otomatis mengisi model regulasi AS yang sesuai (Axxxx), konsistensi fitur terbatas lintas wilayah (Apple Intelligence versi luar negeri, mute shutter, fitur wilayah kesehatan, dll) paling lengkap.\n\n2. Hanya Ubah Kode Wilayah LL (pertahankan akhiran CH/A dan kompatibilitas dual-SIM):\nHanya mengubah kode wilayah (RegionCode) menjadi LL, mempertahankan akhiran wilayah penjualan perangkat asli sepenuhnya (seperti CH/A) dan model regulasi pabrik. Tidak hanya memenuhi akses dasar Apple Intelligence, membuat akhir model di \"Pengaturan -> Tentang Perangkat\" tetap menampilkan CH/A, juga dapat menghindari konflik slot baseband pada model Tiongkok dengan dual SIM fisik + eSIM (seperti 18 Pro / Pro Max) akibat pemetaan model AS tanpa slot kartu."
    static let ipadOS = "Jika Anda saat ini mengatur kata sandi layar kunci alfanumerik campuran, jangan pernah mengaktifkan opsi ini! Setelah diaktifkan, juga jangan pernah mematikan \"Tampilkan Dock di Stage Manager\",否则会导致设备软砖（白苹果循环）。启用 iPadOS 界面后可能出现界面错位、部分应用不兼容等问题。"
    static let support = "Harap cadangkan data penting terlebih dahulu! Jika ada modifikasi yang tidak berlaku sesuai harapan, jangan ajukan permintaan dukungan ke repositori resmi. Banyak fitur juga dibatasi oleh hardware perangkat dan kebijakan server Apple, semua modifikasi ditanggung risikonya sendiri."
    static let mgReset = "Reset MobileGestalt akan menghapus file cache asli sistem dan membiarkan sistem meregenerasinya saat restart. Ini membantu sepenuhnya menghapus modifikasi yang tidak dapat dipulihkan, tetapi ada kemungkinan sangat kecil memicu anomali, harap berhati-hati."
    
    // info
    static let liquidGlass = "Setelah diaktifkan, akan menggunakan mode rendering Liquid Glass iOS 26/27 dengan overhead rendah, dapat mengurangi beban GPU, mengurangi panas perangkat, dan menghemat baterai (berlaku setelah muat ulang atau restart)."
    static let chinaCacheUnlock = "Melalui pustaka sistem yang dimuat dari memori perangkat (libMobileGestalt.dylib), secara real-time menganalisis offset slot biner CacheData secara dinamis, mengatur penanda batasan lapisan bawah versi Tiongkok green-tea menjadi false, dan not-green-tea menjadi true.\n\n• Dapat membuka FaceTime Audio (panggilan suara) dan akses wilayah AI lapisan bawah pada semua perangkat versi Tiongkok;\n• Pada model versi Tiongkok yang memiliki chip eSIM fisik bawaan (seperti iPhone Air dan model chip eUICC internal lainnya), dapat membuka blokir geo-fence sistem terhadap eSIM luar negeri (catatan: motherboard versi Tiongkok dengan dual SIM fisik reguler secara fisik kosong tanpa chip eUICC, tidak dapat menulis kartu virtual melalui perangkat lunak murni).\n\nStrategi keamanan: Hanya diizinkan memodifikasi ketika CacheUUID perangkat, panjang total, bit valid, dan byte padding 100% cocok; harap restart ponsel secara manual setelah diterapkan agar berlaku."
    static let wapiToWifi = "Melalui pustaka sistem perangkat, secara real-time menganalisis offset slot boolean wapi secara dinamis dan mengatur menjadi false, sehingga \"WLAN\" di \"Pengaturan\" sistem dan Pusat Kontrol ditampilkan secara seragam sebagai \"Wi-Fi\" versi internasional.\n\n⚠️ Penting: Setelah diaktifkan, Anda akan 【kehilangan fitur \"Tidak Mengizinkan Koneksi Internet\" khas versi Tiongkok】 (yaitu opsi \"Nonaktif\" di \"Aplikasi yang Menggunakan WLAN dan Data Seluler\")! Logika versi internasional hanya mengizinkan penonaktifan \"Data Seluler\" secara terpisah, tidak dapat melarang aplikasi individual menggunakan koneksi Wi-Fi (seperti keyboard pihak ketiga atau aplikasi offline tidak akan dapat sepenuhnya memutus internet), sekaligus sakelar \"Aktifkan WAPI\" juga akan tersembunyi.\n\nJika Anda perlu mempertahankan kontrol izin \"Tidak Mengizinkan Koneksi Internet\" aplikasi, biarkan opsi ini nonaktif; jika sudah diaktifkan, matikan sakelar ini, terapkan ulang, dan restart ponsel secara manual untuk memulihkan seperti semula."
    static let intInstall = "Opsi ini akan mengaktifkan sebagian fitur debug internal Apple yang tertinggal di iOS versi rilis. Catatan: setelah diaktifkan mungkin memengaruhi sebagian fungsi normal (seperti tidak dapat menginstal ulang aplikasi sistem bawaan dari App Store), dan bertentangan dengan Apple Intelligence."
    static let intBuild = "Sakelar ini terutama digunakan untuk menampilkan info debug penyimpanan internal di aplikasi \"Pengaturan\". Pada sebagian perangkat (terutama iPadOS) mungkin menyebabkan masalah kompatibilitas."
    static let appleIntellInfo = "Mengaktifkan sakelar utama AI generatif on-device (DeviceSupportsGenerativeModelSystems) untuk model lama yang tidak mendukung Apple Intelligence, dan secara otomatis menyinkronkan pembukaan 2 penanda sub-kemampuan berikut yang dinonaktifkan secara default pada chip lama:\n\n• Fitur \"Hapus\" Foto (Photos Clean Up)\n• \"Sintesis Tulisan Tangan\" Catatan (Handwriting Synthesis)\n\nCatatan: Jika model lama perlu benar-benar mengunduh model AI on-device, biasanya juga perlu menggunakan \"Penyamaran Model\" di bawah dan \"Buka Batasan Wilayah\" di atas (harap restart ponsel secara manual setelah modifikasi agar berlaku)."
    static let advAppleIntell = "【Peringatan Pagar Pengaman】Verifikasi probe lapisan bawah pada perangkat asli (iPhone 18 Pro Max · iPhone19,7) mengonfirmasi: Audio Intelligence iOS 27 (rb2tKZxlj0Gm2tBmUQSLqQ, slot #178) pada perangkat iPhone / iPad dalam device tree pabrik secara default bernilai false (0x00), sedangkan Personal Translator (M1n2sAqf33NAOgZRGxQYBA, slot #266) pada hardware native yang didukung (seperti seri iPhone 18 Pro) sudah otomatis aktif true (0x01) dari pabrik.\n\n⚠️ Memaksa mengaktifkan slot eksperimental Audio Intelligence non-native pada iPhone / iPad akan menyebabkan jalur validasi pipeline model generatif sistem terputus — langsung menyebabkan fitur 【\"Kualitas Tinggi\" Hapus (ServerDiffusionInpainting)】 pada foto error dan tidak berfungsi (menampilkan \"Terjadi kesalahan saat menghapus foto ini. Silakan coba lagi nanti.\")!\n\nRekaman panggilan reguler, transkripsi Voice Memos, dan terjemahan sistem semuanya didukung penuh oleh sakelar AI utama, Personal Translator native bawaan perangkat juga akan dikenali dan dipertahankan secara otomatis. Pagar pengaman telah mengunci secara default untuk mencegah pengaktifan tidak sengaja; jika sebelumnya pernah diaktifkan di versi lama, cukup matikan sakelar ini (atau ketuk kartu pemeriksaan di atas untuk perbaikan sekali klik) dan terapkan untuk memulihkan baseline pabrik dan fitur hapus kualitas tinggi."
    static let audioMixInfo = "Melalui pustaka sistem perangkat, secara real-time menganalisis slot boolean biner CacheData CameracinematicAudioTrackRendering (aVL5GE3tx0LSCI/ErfrJGA) secara dinamis dan mengatur menjadi true, membuka fitur \"Audio Mix\" di galeri dan editor video kamera, mendukung empat tingkat mixing pemisahan vokal dan ambient \"Standar / Isolasi Vokal / Studio / Efek Film\" (harap restart ponsel secara manual setelah diterapkan agar berlaku)."
    static let spatialAudioInfo = "Melalui pustaka sistem perangkat, secara real-time menganalisis slot boolean biner CacheData spatial-audio-recording dan spatial-facetime-audio secara dinamis dan menyinkronkan pengaturan menjadi true, membuka kemampuan penangkapan audio spasial 3D saat perekaman video kamera dan rendering medan suara spasial panggilan FaceTime (harap restart ponsel secara manual setelah diterapkan agar berlaku)."
    static let responsiveShutterInfo = "Melalui pustaka sistem perangkat, secara real-time menganalisis slot boolean biner CacheData ResponsiveShutter (gQDt76Te0SPw7N8oTLrBFw) secara dinamis dan mengatur menjadi true, mengurangi latency pemicu dari penekanan tombol rana kamera hingga pipeline imaging, mewujudkan jepretan zero-latency saat jari menekan (harap restart ponsel secara manual setelah diterapkan agar berlaku)."
    static let hypertensionInfo = "Melalui pustaka sistem perangkat, secara real-time menganalisis slot boolean biner CacheData HypertensionNotifications (4fh9efw4o1yaFqkXNCXoeA) secara dinamis dan mengatur menjadi true, membuka evaluasi tren tekanan darah tinggi, notifikasi risiko, dan halaman panduan pencatatan pengukuran di aplikasi \"Kesehatan\" (harap restart ponsel secara manual setelah diterapkan agar berlaku)."
    static let callScreeningGuide = "【Solusi Koeksistensi Emas \"Penanya Panggilan Mandarin\" dan Apple Intelligence Luar Negeri (Fitur Uji)】\n\nApple menerapkan filter suara berbasis \"Locale\" sistem pada penyaringan panggilan: jika wilayah sistem diatur ke \"Amerika Serikat\" akan kehilangan penanya panggilan Mandarin Tiongkok; jika tetap \"Tiongkok Daratan\" akan memblokir Apple Intelligence.\n\nSatu-satunya empat langkah konfigurasi koeksistensi sempurna yang teruji:\n1. MobileGestalt: aktifkan \"Buka Batasan Wilayah (LL / LL/A)\" di halaman ini dan isi model regulasi AS yang sesuai;\n2. Pengaturan Sistem -> Umum -> Bahasa & Wilayah: ubah \"Wilayah\" menjadi 【Taiwan】, bahasa pilihan pertama tetap 【Mandarin Sederhana】;\n3. Pengaturan Sistem -> Apple Intelligence & Siri: atur bahasa Siri ke 【Mandarin (Mandarin - Tiongkok Daratan)】;\n4. Aturan split-routing: guzzoni.apple.com dan *.siri.apple.com harus melalui 【DIRECT langsung + IP asli (always-real-ip)】 untuk mencegah error Siri, hanya arahkan apple-relay.apple.com, gspe1-ssl.ls.apple.com, dan OpenAI ke node AS (dapat mengekspor modul Surge sekali klik di \"Pusat Grup Bersama Aplikasi Lintas Container\")."
    static let expNotice = "【Pemberitahuan Fitur Uji】Semua sakelar di grup ini secara runtime menganalisis slot boolean CacheData asli (QType=11) secara real-time dari libMobileGestalt.dylib perangkat dan memverifikasi CacheUUID, panjang byte total, dan bit valid slot sebelum menulis. Karena tingkat dukungan ISP, sensor, atau daemon wilayah (eligibilityd) lapisan bawah berbeda-beda antar model, sebagian fitur hanya membuka entri UI sistem ketika tidak ada hardware fisik. Harap 【restart ponsel secara manual】 setelah diterapkan untuk memverifikasi efek, dapat dimatikan atau dipulihkan kapan saja dari cadangan."
    static let expShutterMuteInfo = "【Fitur Uji】RegionalBehaviorShutterClick tradisional adalah probe dinamis read-only (slot = -1), penulisan langsung ke CacheExtra tidak efektif. Sakelar ini menggabungkan modifikasi 3 slot boolean CacheData asli:\n• DeviceSupportsRegionalCameraShutterRelaxation = true\n• KeyboardMutePreservesRegionalShutterClickBehavior = false\n• ...ForLegacyDevices = false\nDapat mencoba membuka suara rana kamera wajib pada model versi Jepang (J/A) dan Korea (KH/A) tanpa mengubah wilayah penjualan seluruh perangkat (harap restart ponsel secara manual setelah diterapkan agar berlaku)."
    static let expStudioMicsInfo = "【Fitur Uji】Mengaktifkan slot penangkapan mikrofon array ganda high-low power bersamaan DeviceSupportsConcurrentHPLPMics (dI30ovtFUIeLioNQKDMbGQ), menyediakan penanda kemampuan hardware lapisan bawah untuk overdub studio Voice Memos dan pemisahan vokal multitrack (memerlukan dukungan DSP mikrofon, berlaku setelah restart)."
    static let expPhotoToneInfo = "【Fitur Uji】Sinkron mengaktifkan tiga slot boolean pipeline pasca-pemrosesan imaging PhotosLocalLight, ToneMapping, dan HDRDeferredProcessing, meningkatkan kemampuan redraw cahaya lokal galeri, pemetaan nada generasi baru, dan render delay HDR mendalam (berlaku setelah restart)."
    static let expSpatialStereoInfo = "【Fitur Uji】Sinkron mengaktifkan tiga slot penangkapan video SpatialOverCapture, StereoAudioRecording, dan P3ColorspaceVideoRecording, membuka rekonstruksi sudut pandang spasial ultra-wide, penangkapan audio stereo, dan dukungan encoding video wide color gamut P3 (berlaku setelah restart)."
    static let expCamControlInfo = "【Fitur Uji】Sinkron mengaktifkan empat slot interaksi CameraButtonCapability, TouchSensitiveCameraControl, HardwareDetents, dan CameraHaptics, membuka panel konfigurasi kontrol kamera ketuk lembut/geser zoom kapasitif \"Pengaturan -> Kamera -> Kontrol Kamera\" secara lengkap (model tanpa tombol fisik hanya menampilkan panel pengaturan, berlaku setelah restart)."
    static let expLegacyBatteryInfo = "【Fitur Uji】Mengaktifkan slot DeviceShowsBatteryModelInformationLegacyHW dan DynamicEndOfChargeLegacyHW, mencoba menampilkan tanggal produksi baterai, waktu penggunaan pertama, dan jumlah siklus pengisian presisi di \"Pengaturan -> Baterai / Tentang Perangkat\" iPhone / iPad lama (berlaku setelah restart; juga dapat menggunakan modul \"Telemetri Baterai Fisik dan Termal\" di alat ini untuk membaca data lapisan bawah secara langsung)."
    static let expHighLumAODInfo = "【Fitur Uji】Sinkron mengaktifkan slot HighLuminanceAlwaysOnDisplay dan AlwaysOnDisplayFlipbook, membuka strategi always-on display kecerahan tinggi outdoor dan render frame buffer flipbook hemat daya (catatan: mengaktifkan AOD pada layar non-LTPO akan meningkatkan konsumsi daya standby, berlaku setelah restart)."
    static let expCarPlay2Info = "【Fitur Uji】Mengaktifkan slot DeviceSupportsCarPlay2 (PR+xeEtTAiUN0R25+EYGfw), mengaktifkan dukungan protokol车载 CarPlay Ultra multi-layar instrumen full LCD generasi baru (berlaku setelah restart)."
    static let expTouch120Info = "【Fitur Uji】Mengaktifkan slot TouchDelivery120Hz (2OK50OGmkXM1ospsh766WQ), mengaktifkan pipeline pengiriman event sampling touch 120Hz ke sistem (catatan: panel layar fisik 60Hz tidak dapat menembus refresh rate gambar 60fps, hanya berlaku pada lapisan pengiriman sampling touch, berlaku setelah restart)."
    static let expHearingAidInfo = "【Fitur Uji】Sinkron mengaktifkan tiga slot boolean berurutan hearingaid-audio-equalization, hearingaid-low-energy-audio, dan hearingaid-power-reduction, bekerja sama dengan AirPods Pro 2 / 3 untuk mencoba membuka ekualisasi kesehatan pendengaran dan kemampuan bantu dengar klinis (sebagian wilayah masih dibatasi oleh pagar medis eligibilityd, berlaku setelah restart)."
    static let expSleepApneaInfo = "【Fitur Uji】Mengaktifkan slot DeviceSupportsBreathingDisturbancesMeasurements (e0HV2blYUDBk/MsMEQACNA), membuka halaman evaluasi tren risiko sleep apnea \"Kesehatan -> Pernapasan -> Gangguan Pernapasan\" (memerlukan data pemantauan tidur Apple Watch, berlaku setelah restart)."
    static let expUSBloodOxygenInfo = "【Fitur Uji】Mengatur slot DeviceSupportsUSLegallyCompliantBloodOxygen (E4vGMChwcVRKD8hMVxnRvg) menjadi false, membuka blokir pengukuran SpO2 lapisan perangkat lunak perangkat versi AS (LL/A) yang dipicu oleh larangan paten (model versi Tiongkok secara native sudah false, tidak perlu diaktifkan, berlaku setelah restart)."
    static let expWorkoutUltraInfo = "【Fitur Uji】Sinkron mengaktifkan slot WorkoutUltraMode dan DeviceSupportsTimeInDaylight, membuka mode bantuan olahraga outdoor ekstrem dan entri statistik pemantauan cahaya lingkungan \"Waktu di Bawah Sinar Matahari\" Kesehatan (berlaku setelah restart)."
    static let expSiriHubInfo = "【Peringatan Pagar Pengaman】Pengujian perangkat asli menunjukkan: DeviceSupportsSiriHub (waGD2UTpntjbDXD1r3oALQ) adalah penanda routing eksklusif hardware hub rumah dengan layar (HomeAccessory / HomePad).\n\n⚠️ Mengaktifkannya pada iPhone / iPad akan menyebabkan assistantd meminta aset model SiriHub yang tidak ada, membuat Apple Intelligence macet tak terbatas pada \"Sedang menambahkan konten dukungan Siri, sebelum pembaruan selesai, Siri tidak dapat digunakan\"!\n\nPagar pengaman telah mengunci secara default untuk mencegah pengaktifan baru opsi ini pada iPhone / iPad; jika Anda pernah mengaktifkan sakelar ini di versi lama, cukup matikan opsi ini (atau gunakan kartu pemeriksaan Apple Intelligence di atas untuk perbaikan sekali klik) dan restart ponsel secara manual untuk memulihkan normal."
    static let spoofUseless = "Penyamaran model perangkat dapat menyebabkan fitur hardware seperti Face ID tidak berfungsi! Hardware perangkat Anda sendiri sudah mendukung Apple Intelligence secara native, tidak perlu memodifikasi opsi ini (perangkat versi Tiongkok hanya perlu mengaktifkan \"Buka Batasan Wilayah\" di atas)."
    static let spoofAI = "Untuk model lama yang tidak mendukung Apple Intelligence, hanya menyalakan sakelar tidak dapat mengunduh model AI on-device, juga perlu menyamar sebagai model yang didukung; namun penyamaran model dapat menyebabkan Face ID tidak berfungsi. Setelah membatalkan penyamaran model, jangan pernah masuk lagi ke halaman \"Pengaturan -> Apple Intelligence & Siri\"."
    static let subtype = "Hanya modifikasi Subtype perangkat jika Anda ingin menyesuaikan posisi vertikal Dynamic Island atau karakteristik resolusi layar. Jika ingin mengaktifkan Dynamic Island pada model non-Dynamic Island, harap gunakan bersama sakelar \"Aktifkan Dynamic Island\" di bawah!"
    static let mgResetComp = "Cache MobileGestalt saat ini telah dihapus dan cadangan lama telah diarsipkan dengan aman. Harap segera 【restart perangkat Anda secara manual】, sistem akan meregenerasi parameter pabrik 100% murni dari fuse hardware saat boot."
    static let revertComp = "Cadangan pabrik perangkat telah dipulihkan melalui verifikasi SHA-256 dan validasi penulisan fisik disk, dan residu sakelar kustom lokal telah disinkronkan dan dibersihkan. Disarankan 【restart ponsel secara manual sekali】 untuk memastikan semua parameter lapisan bawah sepenuhnya dipulihkan."
    static let revertConfirm = "Akan segera mengeksekusi pemulihan parameter pabrik perangkat:\n\n1. Secara ketat memverifikasi ringkasan SHA-256, versi sistem, CacheUUID, dan model hardware asli dari cadangan pabrik;\n2. Memulihkan MobileGestalt melalui penulisan disk in-place tanpa jendela zero-byte (pwrite + F_FULLFSYNC) dan verifikasi baca balik;\n3. Sinkron mereset nilai kunci kustom lokal, nama model kustom, dan sakelar gerbang out-of-bound, mencegah penulisan balik residu."
    static let globalFactoryRestoreConfirm = "Akan segera mengeksekusi pemulihan parameter pabrik asli semua modul sekali klik:\n\n1. Memulihkan dan memverifikasi cadangan pabrik MobileGestalt perangkat (termasuk SHA-256 dan verifikasi penulisan fisik disk);\n2. Menghapus teks bagian bawah layar kunci, plat nama aset perangkat, dan residu pseudo-supervisi pihak ketiga (otomatis melindungi MDM perusahaan asli);\n3. Membersihkan cache keypad dial kustom dan mereset semua status preferensi lokal."

    // settings
    static let mgResetSavWarn = "Sebelum meregenerasi cadangan asli, pastikan semua modifikasi saat ini telah dipulihkan, jika tidak, modifikasi yang sedang aktif akan ditulis ke cadangan asli baru!"
    static let hidTweakWarn = "Setelah menampilkan item modifikasi tersembunyi, Anda akan dapat melihat sakelar lapisan bawah yang sudah didukung native atau tidak kompatibel dengan model saat ini. Perubahan buta dapat menyebabkan fungsi abnormal bahkan kehilangan data!"
}

enum MGKey {
    // bindings
    static let ipadosCacheEx = [
        "uKc7FPnEO++lVhHWHFlGbQ", // ipad
        "mG0AnH/Vy1veoqoLRAIgTA", // MedusaFloatingLiveAppCapability
        "UCG5MkVahJxG1YULbbd5Bg", // MedusaOverlayAppCapability
        "ZYqko/XM5zD3XBfN5RmaXA", // MedusaPinnedAppCapability
        "nVh/gwNpy7Jv1NOk00CMrw", // MedusaPIPCapability,
        "qeaj75wk3HF4DwQ8qbIi7g", // DeviceSupportsEnhancedMultitasking
    ]
    
    // hardware features
    static let island = "YlEtTtHlNesRBMal1CqRaA" // DeviceSupportsDynamicIsland
    static let AOTime = "j8/Omm6s1lsmTDFsXjsBfA" // DeviceSupportsAlwaysOnTime
    static let AOD = "2OOJf1VhaM7NxfRok3HbWQ" // DeviceSupportsAlwaysOnDisplay
    static let AODVibrancy = "ykpu7qyhqFweVMKtxNylWA" // DeviceSupportsAODVibrancy
    static let liquidGlassLowPower = "SAGvsp6O6kAQ4fEfDJpC4Q" // Liquid Glass Low-Power Rendering
    static let chargeLim = "37NVydb//GP/GrhuTN+exg" // DeviceSupports80ChargeLimit
    static let bootChime = "QHxt+hGLaBPbQJbXiUJX3w" // DeviceSupportsBootChime
    
    // internal
    static let intInstall = "EqrsVvjcYDdxHBiQmGhAWw" // apple-internal-install
    static let intBuild = "LBJfwOEzExRxzlAnSuI7eg" // InternalBuild
    
    // eligibility
    static let srd = "XYlJKKkj2hztRP1NWWnhlw" // ResearchFuse
    static let appIntell = "A62OafQ85EJAiiqKn4agtg" // DeviceSupportsGenerativeModelSystems
    static let photosCleanUp = "XNCjqOupLM/S8fNyxRNQTA" // Photos Clean Up
    static let handwritingSynth = "YgYIIViDt1kgzyIsIV61vA" // Handwriting Synthesis
    static let appIntellAllKeys = [
        "A62OafQ85EJAiiqKn4agtg", // DeviceSupportsGenerativeModelSystems
        "XNCjqOupLM/S8fNyxRNQTA", // Photos Clean Up
        "YgYIIViDt1kgzyIsIV61vA", // Handwriting Synthesis
    ]
    static let audioIntell = "rb2tKZxlj0Gm2tBmUQSLqQ" // supports-audio-intelligence
    static let personalTranslator = "M1n2sAqf33NAOgZRGxQYBA" // supports-personal-translator
    static let advAppIntellKeys = [
        "rb2tKZxlj0Gm2tBmUQSLqQ", // Audio Intelligence
        "M1n2sAqf33NAOgZRGxQYBA", // Personal Translator
    ]
    static let advAppIntellRules: [MGSlotRule] = [
        MGSlotRule(key: "rb2tKZxlj0Gm2tBmUQSLqQ", targetValue: true, required: false),
        MGSlotRule(key: "M1n2sAqf33NAOgZRGxQYBA", targetValue: true, required: false),
    ]
    static let regionCode = "h63QSdBCiT/z0WU6rdQv6Q" // RegionCode
    static let regionInfo = "zHeENZu+wbg7PUprwNwBWg" // RegionInfo
    static let regionSysconfig = "yK+xavymRGZ3xWc1tb8XDg" // RegionInfoFromSysconfig
    static let regModelNumber = "97JDvERpVwO+GHtthIh7hA" // RegulatoryModelNumber

    // media, camera & health (CacheData boolean slots)
    static let audioMix = "aVL5GE3tx0LSCI/ErfrJGA"            // CameracinematicAudioTrackRendering (Audio Mix)
    static let spatialAudioRec = "X6NGcYcvHmbqlR8hLXASJA"     // spatial-audio-recording
    static let spatialFaceTimeAudio = "/EVOCjM/Nmb2roP5ebtEFA"// spatial-facetime-audio
    static let spatialAudioAllKeys = [
        "X6NGcYcvHmbqlR8hLXASJA",
        "/EVOCjM/Nmb2roP5ebtEFA",
    ]
    static let responsiveShutter = "gQDt76Te0SPw7N8oTLrBFw"   // ResponsiveShutter
    static let hypertensionNotif = "4fh9efw4o1yaFqkXNCXoeA"   // HypertensionNotifications
    static let mediaHealthAllKeys = [
        "aVL5GE3tx0LSCI/ErfrJGA",
        "X6NGcYcvHmbqlR8hLXASJA",
        "/EVOCjM/Nmb2roP5ebtEFA",
        "gQDt76Te0SPw7N8oTLrBFw",
        "4fh9efw4o1yaFqkXNCXoeA",
    ]
    
    // prefs
    static let crashDet = "HCzWusHQwZDea6nNhaKndw" // DeviceSupportsCollisionSOS
    static let pwm = "6IejgN+1Fmu5/QrZFOIeNw" // DeviceSupportsPulseWidthMaximization
    static let appPencil = "yhHcB0iH0d1XzPO/CFd3ow" // DeviceSupportsApplePencil
    static let camButton = "CwvKxM2cEogD3p+HYgaW0Q" // CameraButtonCapability
    static let grapPefr = "oOV1jhJbdV3AddkcCg0AEA" // apple-graphics-performance-tier
    static let actButton = "cT44WE1EohiwRzhsZ8xEsw" // RingerButtonCapability
    static let tapToWake = "yZf3GTRMGTuwSV/lD7Cagw" // DeviceSupportsTapToWake
    
    // ipados
    static let stageMgr = "qeaj75wk3HF4DwQ8qbIi7g" // DeviceSupportsEnhancedMultitasking
    
    // lookup
    static let deviceClass = "+3Uf0Pm5F8Xy7Onyvko0vA" // DeviceClass
    static let artwork = "oPeik/9e8lQWMszEjbPzng" // ArtworkTraits
    static let prodType = "h9jDsbgj7xIVeIQ8S3/X3Q" // ProductType
    static let modelNameOuter1 = "Z/dqyWS6OZTRy10UcmUAhw" // DeviceProductDescription
    static let modelNameOuter2 = "bbtR9jQx50Fv5Af/affNtA" // MarketingNameString

    // [Fitur Uji] Experimental CacheData Boolean Slot Keys
    static let shutterRelaxation = "P4ZJVy/zYuLy4ejRKP+0DA"
    static let shutterKeyboardMutePreserve = "bGUN8lS6sYzy3xhePubp8A"
    static let shutterLegacyMutePreserve = "Bim3FC83Te8QX1kfSpqYKQ"
    static let concurrentHPLPMics = "dI30ovtFUIeLioNQKDMbGQ"
    static let photosLocalLight = "m9ORTKMgu9A+zF+A61Zz5A"
    static let toneMapping = "Lcu6Zck+C/+AMO8qULacDw"
    static let hdrDeferredProcessing = "JkZlE8z9YwHjE1hnbMhcgA"
    static let spatialOverCapture = "SjQQ07G8UacM7E69G7dPbg"
    static let stereoAudioRec = "YlK+0xmxNWhNn/+r8SM8kA"
    static let p3VideoRec = "1eBwtCIwbIDdC80wiyzfow"
    static let touchSensitiveCamControl = "lyJZrSDc8J8eQ5Zb7A1Rvw"
    static let hardwareDetents = "V9pLLbPQhyb75bbdTioZVw"
    static let cameraHaptics = "XriAxQ+JY1z5nt5f3ftXVw"
    static let legacyBatteryInfo = "Rq0MF/w+gXM66Ii4fkWOzg"
    static let legacyDynamicEndOfCharge = "nfR1IphTGCaoFNu3NrCtWQ"
    static let highLuminanceAOD = "7brdL5xrEUWnlF9C0kdg5A"
    static let aodFlipbook = "aoJSd/MXk7M40NgXTM6x+g"
    static let carPlay2 = "PR+xeEtTAiUN0R25+EYGfw"
    static let touchDelivery120Hz = "2OK50OGmkXM1ospsh766WQ"
    static let hearingAidEQ = "SMgTCc2v9AU2ziIHRX8qww"
    static let hearingAidLE = "RyXm3yMC4ejlFvwlEI509w"
    static let hearingAidPowerRed = "u3c0R+31Df4SUTHrICQkTg"
    static let breathingDisturbances = "e0HV2blYUDBk/MsMEQACNA"
    static let usBloodOxygen = "E4vGMChwcVRKD8hMVxnRvg"
    static let workoutUltra = "fu+4kyf8VcMBtgbMyJlLtg"
    static let timeInDaylight = "8gVfz9/8R1OtWBBtI0o/+Q"
    static let siriHub = "waGD2UTpntjbDXD1r3oALQ"
    static let onDeviceSiri = "O/7gbXWA5X2IRPVtDRU+bw"
    static let modelPruning = "m4xs4mhvxnAopYrApoLDMw"

    static let experimentalCacheSlotKeys: [String] = [
        shutterRelaxation,
        shutterKeyboardMutePreserve,
        shutterLegacyMutePreserve,
        concurrentHPLPMics,
        photosLocalLight,
        toneMapping,
        hdrDeferredProcessing,
        spatialOverCapture,
        stereoAudioRec,
        p3VideoRec,
        touchSensitiveCamControl,
        hardwareDetents,
        cameraHaptics,
        legacyBatteryInfo,
        legacyDynamicEndOfCharge,
        highLuminanceAOD,
        aodFlipbook,
        carPlay2,
        touchDelivery120Hz,
        hearingAidEQ,
        hearingAidLE,
        hearingAidPowerRed,
        breathingDisturbances,
        usBloodOxygen,
        workoutUltra,
        timeInDaylight,
        siriHub,
        onDeviceSiri,
        modelPruning
    ]
}

struct MGSlotRule: Equatable {
    let key: String
    let targetValue: Bool
    var required: Bool = true
}

final class GestaltStore: ObservableObject {
    static let shared = GestaltStore()
    
    @Published var mgCurrentDict = NSMutableDictionary()
    var cacheExtra: NSMutableDictionary {
        return mgCurrentDict["CacheExtra"] as? NSMutableDictionary ?? NSMutableDictionary()
    }
    
    init() {}
    
    // MARK: helpers
    func originalCacheExtraValue(forKey key: String) -> Any? {
        guard let ogDict = NSDictionary(contentsOf: MGURL.savedGestaltURL),
              let ogCacheExtra = ogDict["CacheExtra"] as? NSDictionary else {
            return nil
        }
        return ogCacheExtra[key]
    }
    
    func restoreOrRemoveKey(_ key: String) {
        if let ogVal = originalCacheExtraValue(forKey: key) {
            self.cacheExtra[key] = ogVal
        } else {
            self.cacheExtra.removeObject(forKey: key)
        }
    }

    func disableBooleanExtraKey(_ key: String, enableValue: Int = 1) {
        if let ogVal = originalCacheExtraValue(forKey: key) {
            // If OriginalGestalt.plist was captured on an already-polluted system (e.g. another tool injected `1`),
            // strip the polluted key instead of restoring `1` so the user can turn the switch off directly.
            if let ogNum = ogVal as? NSNumber, ogNum.intValue == enableValue {
                self.cacheExtra.removeObject(forKey: key)
            } else {
                self.cacheExtra[key] = ogVal
            }
        } else {
            self.cacheExtra.removeObject(forKey: key)
        }
    }
    
    // MARK: actions
    func mgPullKeys(_ keys: [String], enableValue: Int = 1) {
        for key in keys {
            disableBooleanExtraKey(key, enableValue: enableValue)
        }
    }
    
    func isKeyEnabled(_ key: String, enableValue: Int = 1) -> Bool {
        if let num = self.cacheExtra[key] as? NSNumber, num.intValue == enableValue {
            return true
        }
        if case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict),
           let slotIdx = layout.slotIndex(forKey: key),
           layout.validateSingleBooleanSlot(slotIdx, in: data),
           data[slotIdx * 8] == 1 {
            let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
            let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) ?? false
            if !origVal {
                return true
            }
        }
        return false
    }

    func isEnabled(_ keys: [String], enableValue: Int = 1) -> Bool {
        guard !keys.isEmpty else { return false }
        return keys.allSatisfy { self.isKeyEnabled($0, enableValue: enableValue) }
    }
    
    func strVal(forKey key: String) -> String {
        let value = self.cacheExtra[key] as? String ?? ""
        return value
    }
    
    // MARK: bindings
    func mgKeyBinding(_ keys: [String], defaultValue: Int = 0, enableValue: Int = 1) -> Binding<Bool> {
        return Binding(get: {
            guard !keys.isEmpty else {
                return false
            }
            return keys.allSatisfy { self.isKeyEnabled($0, enableValue: enableValue) }
        }, set: { enabled in
            self.objectWillChange.send()
            for key in keys {
                if enabled {
                    self.cacheExtra[key] = enableValue
                } else {
                    self.disableBooleanExtraKey(key, enableValue: enableValue)
                }
            }
            // Dual-write CacheData slot if this key also has a valid boolean slot in CacheData
            // (bypasses libMobileGestalt's _MGCacheSetValueForKey tbnz validity short-circuit)
            if case .success((let layout, var data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                var touchedSlot = false
                for key in keys {
                    if let slotIdx = layout.featureSlotIndices[key],
                       layout.validateSingleBooleanSlot(slotIdx, in: data) {
                        if enabled {
                            data[slotIdx * 8] = (enableValue != 0) ? 1 : 0
                        } else {
                            let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) ?? false
                            data[slotIdx * 8] = origVal ? 1 : 0
                        }
                        touchedSlot = true
                    }
                }
                if touchedSlot {
                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    testDict["CacheData"] = data
                    if case .success = layout.validatePlist(testDict) {
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        })
    }
    
    func mgTrollPadBinding() -> Binding<Bool> {
        return Binding(get: {
            guard let firstKey = MGKey.ipadosCacheEx.first else {
                return false
            }
            return (self.cacheExtra[firstKey] as? NSNumber)?.intValue == 1
        }, set: { enabled in
            if enabled {
                Alertinator.shared.alert(
                    title: "Pagar pengaman memblokir operasi berisiko tinggi!",
                    body: "Memaksa mengaktifkan antarmuka iPadOS pada iPhone memerlukan manipulasi offset CacheData yang tidak terverifikasi, sangat mudah memicu reboot bootloop tak terbatas dan pembekuan touch saat kata sandi layar kunci atau rotasi layar, pagar anti-bootloop telah menonaktifkan fitur ini secara permanen."
                )
            } else {
                self.objectWillChange.send()
                for key in MGKey.ipadosCacheEx {
                    self.disableBooleanExtraKey(key, enableValue: 1)
                }
            }
        })
    }
    
    var preferredRegionUnlockMode: MGRegionUnlockMode {
        get {
            let raw = UserDefaults.standard.string(forKey: MGRegionUnlockMode.defaultsKey) ?? MGRegionUnlockMode.fullUS.rawValue
            return MGRegionUnlockMode(rawValue: raw) ?? .fullUS
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: MGRegionUnlockMode.defaultsKey)
        }
    }

    var currentRegionUnlockMode: MGRegionUnlockMode {
        if (self.cacheExtra[MGKey.regionCode] as? String) == "LL" {
            return ((self.cacheExtra[MGKey.regionSysconfig] as? String) == "LL/A") ? .fullUS : .regionCodeOnly
        }
        return preferredRegionUnlockMode
    }

    func isConfirmedChinaHardwareFromCacheData() -> Bool {
        let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
        if case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict, checkWapiSlot: true) {
            if let origFlags = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig) {
                if origFlags.greenTea || origFlags.wapi == true {
                    return true
                }
            }
            if let wOff = layout.wapiOffset, data[wOff] == 1 {
                return true
            }
        }
        return false
    }

    private func restoreNonUSRegionSysconfig() {
        if let ogSys = originalCacheExtraValue(forKey: MGKey.regionSysconfig) as? String, !ogSys.isEmpty {
            if ogSys == "LL/A" && isConfirmedChinaHardwareFromCacheData() {
                self.cacheExtra[MGKey.regionSysconfig] = "CH/A"
            } else {
                self.cacheExtra[MGKey.regionSysconfig] = ogSys
            }
        } else if isConfirmedChinaHardwareFromCacheData() {
            self.cacheExtra[MGKey.regionSysconfig] = "CH/A"
        } else {
            self.cacheExtra.removeObject(forKey: MGKey.regionSysconfig)
        }
    }

    private func restoreNonUSRegulatoryModel() {
        let prodType = originalHardwareProductType()
        if let ogReg = originalCacheExtraValue(forKey: MGKey.regModelNumber) as? String, !ogReg.isEmpty {
            if let usModel = usRegulatoryModelNumber(productType: prodType, originalRegModel: ""),
               ogReg == usModel,
               isConfirmedChinaHardwareFromCacheData(),
               let cnModel = chinaRegulatoryModelNumber(productType: prodType) {
                self.cacheExtra[MGKey.regModelNumber] = cnModel
            } else {
                self.cacheExtra[MGKey.regModelNumber] = ogReg
            }
        } else if isConfirmedChinaHardwareFromCacheData(),
                  let cnModel = chinaRegulatoryModelNumber(productType: prodType) {
            self.cacheExtra[MGKey.regModelNumber] = cnModel
        } else {
            self.cacheExtra.removeObject(forKey: MGKey.regModelNumber)
        }
    }

    func mgRegionRestrictionsBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return self.cacheExtra[MGKey.regionCode] as? String == "LL"
            },
            set: { enabled in
                self.objectWillChange.send()
                if enabled {
                    Alertinator.shared.alert(title: "Pemberitahuan Buka Batasan Wilayah", body: MGMsg.region)
                    self.applyRegionUnlock(mode: self.preferredRegionUnlockMode)
                } else {
                    if let ogCode = self.originalCacheExtraValue(forKey: MGKey.regionCode) as? String, !ogCode.isEmpty {
                        if ogCode == "LL" && self.isConfirmedChinaHardwareFromCacheData() {
                            self.cacheExtra[MGKey.regionCode] = "CH"
                        } else {
                            self.cacheExtra[MGKey.regionCode] = ogCode
                        }
                    } else if self.isConfirmedChinaHardwareFromCacheData() {
                        self.cacheExtra[MGKey.regionCode] = "CH"
                    } else {
                        self.cacheExtra.removeObject(forKey: MGKey.regionCode)
                    }
                    if raveSupported() {
                        self.cacheExtra.removeObject(forKey: MGKey.regionInfo)
                    } else {
                        self.restoreOrRemoveKey(MGKey.regionInfo)
                    }
                    self.restoreNonUSRegionSysconfig()
                    self.restoreNonUSRegulatoryModel()
                }
            }
        )
    }

    func mgRegionUnlockModeBinding() -> Binding<MGRegionUnlockMode> {
        return Binding<MGRegionUnlockMode>(
            get: {
                return self.currentRegionUnlockMode
            },
            set: { newMode in
                self.objectWillChange.send()
                self.preferredRegionUnlockMode = newMode
                if (self.cacheExtra[MGKey.regionCode] as? String) == "LL" {
                    self.applyRegionUnlock(mode: newMode)
                }
            }
        )
    }

    func applyRegionUnlock(mode: MGRegionUnlockMode) {
        self.cacheExtra[MGKey.regionCode] = "LL"
        switch mode {
        case .fullUS:
            self.cacheExtra[MGKey.regionSysconfig] = "LL/A"
            if !raveSupported(), self.originalCacheExtraValue(forKey: MGKey.regionInfo) != nil {
                self.cacheExtra[MGKey.regionInfo] = "LL/A"
            } else {
                self.cacheExtra.removeObject(forKey: MGKey.regionInfo)
            }
            // Always prefer true factory hardware ProductType so model spoofing never mismatches US A-model number
            let prodType = originalHardwareProductType()
            let ogRegModel = (self.originalCacheExtraValue(forKey: MGKey.regModelNumber) as? String) ?? (self.cacheExtra[MGKey.regModelNumber] as? String) ?? ""
            if let usModel = usRegulatoryModelNumber(productType: prodType, originalRegModel: ogRegModel) {
                self.cacheExtra[MGKey.regModelNumber] = usModel
            }
        case .regionCodeOnly:
            if raveSupported() {
                self.cacheExtra.removeObject(forKey: MGKey.regionInfo)
            } else {
                self.restoreOrRemoveKey(MGKey.regionInfo)
            }
            self.restoreNonUSRegionSysconfig()
            self.restoreNonUSRegulatoryModel()
        }
    }

    func applyUSRegionAndRegulatoryModel() {
        applyRegionUnlock(mode: .fullUS)
    }
    
    func mgRegModelBinding() -> Binding<String> {
        return Binding<String>(
            get: {
                return self.cacheExtra[MGKey.regModelNumber] as? String ?? ""
            },
            set: { newValue in
                self.objectWillChange.send()
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.restoreOrRemoveKey(MGKey.regModelNumber)
                } else {
                    self.cacheExtra[MGKey.regModelNumber] = trimmed
                }
            }
        )
    }

    // MARK: - Dynamic CacheData Resolution & Strictly Gated Bindings

    func canModifyGreenTeaCache() -> Bool {
        if case .success = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) {
            return true
        }
        return false
    }

    func canModifyWapiCache() -> Bool {
        if case .success((let layout, _)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict, checkWapiSlot: true),
           layout.wapiOffset != nil {
            return true
        }
        return false
    }

    func canModifyFeatureSlot(_ keys: [String]) -> Bool {
        guard !keys.isEmpty,
              case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) else {
            return false
        }
        return keys.allSatisfy { key in
            guard let slotIdx = layout.featureSlotIndices[key] else { return false }
            return layout.validateSingleBooleanSlot(slotIdx, in: data)
        }
    }

    func isFeatureSlotNativeEnabled(_ keys: [String]) -> Bool {
        guard !keys.isEmpty,
              case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) else {
            return false
        }
        let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
        return keys.allSatisfy { key in
            guard let slotIdx = layout.featureSlotIndices[key],
                  layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                return false
            }
            return MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) == true
        }
    }

    func mgFeatureSlotBinding(_ keys: [String], infoTitle: String? = nil, infoMessage: String? = nil) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard !keys.isEmpty,
                      case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) else {
                    return false
                }
                return keys.allSatisfy { key in
                    guard let slotIdx = layout.featureSlotIndices[key],
                          layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                        return false
                    }
                    return data[slotIdx * 8] == 1
                }
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure(let err):
                    Alertinator.shared.alert(title: "Resolusi dinamis gagal, modifikasi ditolak!", body: err.localizedDescription)
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    for key in keys {
                        guard let slotIdx = layout.featureSlotIndices[key],
                              layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                            Alertinator.shared.alert(title: "Sistem saat ini tidak mendukung slot ini!", body: "Tidak dapat memverifikasi validitas slot \(key) di pustaka sistem dan cache saat ini, modifikasi ditolak.")
                            return
                        }
                        if enabled {
                            data[slotIdx * 8] = 1
                        } else {
                            let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: key, layout: layout, savedOriginalDict: savedOrig) ?? false
                            data[slotIdx * 8] = origVal ? 1 : 0
                        }
                    }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    if let testExtra = testDict["CacheExtra"] as? NSMutableDictionary {
                        for key in keys {
                            testExtra.removeObject(forKey: key)
                        }
                    }
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict) {
                    case .failure(let err):
                        Alertinator.shared.alert(title: "Validasi data cache gagal, modifikasi ditolak!", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        for key in keys {
                            self.cacheExtra.removeObject(forKey: key)
                        }
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func canModifySlotRules(_ rules: [MGSlotRule]) -> Bool {
        guard !rules.isEmpty,
              case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) else {
            return false
        }
        var matchedCount = 0
        for rule in rules {
            if let slotIdx = layout.featureSlotIndices[rule.key],
               layout.validateSingleBooleanSlot(slotIdx, in: data) {
                matchedCount += 1
            } else if rule.required {
                return false
            }
        }
        return matchedCount > 0
    }

    func isSlotRulesNativeSatisfied(_ rules: [MGSlotRule]) -> Bool {
        guard !rules.isEmpty,
              case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) else {
            return false
        }
        let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
        var resolvedAny = false
        for rule in rules {
            guard let slotIdx = layout.featureSlotIndices[rule.key],
                  layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                if rule.required { return false }
                continue
            }
            resolvedAny = true
            guard let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: rule.key, layout: layout, savedOriginalDict: savedOrig),
                  origVal == rule.targetValue else {
                return false
            }
        }
        return resolvedAny
    }

    func mgSlotRulesBinding(_ rules: [MGSlotRule]) -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard !rules.isEmpty,
                      case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) else {
                    return false
                }
                var resolvedAny = false
                for rule in rules {
                    guard let slotIdx = layout.featureSlotIndices[rule.key],
                          layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                        if rule.required { return false }
                        continue
                    }
                    resolvedAny = true
                    let currentBit = (data[slotIdx * 8] == 1)
                    if currentBit != rule.targetValue {
                        return false
                    }
                }
                return resolvedAny
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure(let err):
                    Alertinator.shared.alert(title: "Resolusi dinamis gagal, modifikasi ditolak!", body: err.localizedDescription)
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    var touchedKeys: [String] = []
                    for rule in rules {
                        guard let slotIdx = layout.featureSlotIndices[rule.key],
                              layout.validateSingleBooleanSlot(slotIdx, in: data) else {
                            if rule.required {
                                Alertinator.shared.alert(title: "Sistem saat ini tidak mendukung slot eksperimental ini!", body: "Tidak dapat memverifikasi validitas slot \(rule.key) di pustaka sistem dan cache saat ini, modifikasi ditolak.")
                                return
                            }
                            continue
                        }
                        if enabled {
                            data[slotIdx * 8] = rule.targetValue ? 1 : 0
                        } else {
                            let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: rule.key, layout: layout, savedOriginalDict: savedOrig) ?? (!rule.targetValue)
                            data[slotIdx * 8] = origVal ? 1 : 0
                        }
                        touchedKeys.append(rule.key)
                    }
                    guard !touchedKeys.isEmpty else { return }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    if let testExtra = testDict["CacheExtra"] as? NSMutableDictionary {
                        for key in touchedKeys {
                            testExtra.removeObject(forKey: key)
                        }
                    }
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict) {
                    case .failure(let err):
                        Alertinator.shared.alert(title: "Validasi data cache gagal, modifikasi ditolak!", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        for key in touchedKeys {
                            self.cacheExtra.removeObject(forKey: key)
                        }
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func isSiriHubConflictActive() -> Bool {
        if (self.cacheExtra[MGKey.siriHub] as? NSNumber)?.intValue == 1 {
            return true
        }
        if case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict),
           let slotIdx = layout.featureSlotIndices[MGKey.siriHub],
           layout.validateSingleBooleanSlot(slotIdx, in: data),
           data[slotIdx * 8] == 1 {
            let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
            let origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: MGKey.siriHub, layout: layout, savedOriginalDict: savedOrig) ?? false
            return !origVal
        }
        return false
    }

    func mgSafeSiriHubGuardrailBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return self.isSiriHubConflictActive()
            },
            set: { enabled in
                if enabled {
                    Alertinator.shared.alert(
                        title: "Pagar pengaman memblokir sakelar konflik!",
                        body: MGMsg.expSiriHubInfo
                    )
                    return
                }
                let groupKeys = [MGKey.siriHub, MGKey.onDeviceSiri, MGKey.modelPruning]
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure:
                    self.objectWillChange.send()
                    for k in groupKeys {
                        self.disableBooleanExtraKey(k, enableValue: 1)
                    }
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    for k in groupKeys {
                        if let slotIdx = layout.featureSlotIndices[k],
                           layout.validateSingleBooleanSlot(slotIdx, in: data) {
                            // Never re-enable siriHub on iPhone/iPad even if OriginalGestalt was polluted
                            let origVal: Bool
                            if k == MGKey.siriHub {
                                origVal = false
                            } else {
                                origVal = MGCacheDataCoordinator.shared.originalSlotValue(forKey: k, layout: layout, savedOriginalDict: savedOrig) ?? false
                            }
                            data[slotIdx * 8] = origVal ? 1 : 0
                        }
                    }
                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    if let testExtra = testDict["CacheExtra"] as? NSMutableDictionary {
                        for k in groupKeys {
                            testExtra.removeObject(forKey: k)
                        }
                    }
                    testDict["CacheData"] = data
                    if case .success = layout.validatePlist(testDict) {
                        self.objectWillChange.send()
                        for k in groupKeys {
                            self.cacheExtra.removeObject(forKey: k)
                        }
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func isAdvAppleIntellConflictActive() -> Bool {
        if isAdvAppleIntellHD() {
            return false
        }
        for key in MGKey.advAppIntellKeys {
            if (self.cacheExtra[key] as? NSNumber)?.intValue == 1 {
                return true
            }
        }
        if case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
            let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
            for key in MGKey.advAppIntellKeys {
                if let slotIdx = layout.featureSlotIndices[key],
                   layout.validateSingleBooleanSlot(slotIdx, in: data),
                   data[slotIdx * 8] == 1 {
                    if !isAdvAISlotNativeTrue(key, layout: layout, savedOrig: savedOrig) {
                        return true
                    }
                }
            }
        }
        return false
    }

    func mgSafeAdvAppleIntellGuardrailBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                return self.isAdvAppleIntellConflictActive()
            },
            set: { enabled in
                if enabled {
                    Alertinator.shared.alert(
                        title: "Pagar pengaman memblokir sakelar konflik!",
                        body: MGMsg.advAppleIntell
                    )
                    return
                }
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure:
                    self.objectWillChange.send()
                    for k in MGKey.advAppIntellKeys {
                        self.disableBooleanExtraKey(k, enableValue: 1)
                    }
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    for k in MGKey.advAppIntellKeys {
                        if let slotIdx = layout.featureSlotIndices[k],
                           layout.validateSingleBooleanSlot(slotIdx, in: data) {
                            let nativeVal = isAdvAISlotNativeTrue(k, layout: layout, savedOrig: savedOrig)
                            data[slotIdx * 8] = nativeVal ? 1 : 0
                        }
                    }
                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    if let testExtra = testDict["CacheExtra"] as? NSMutableDictionary {
                        for k in MGKey.advAppIntellKeys {
                            testExtra.removeObject(forKey: k)
                        }
                    }
                    testDict["CacheData"] = data
                    if case .success = layout.validatePlist(testDict) {
                        self.objectWillChange.send()
                        for k in MGKey.advAppIntellKeys {
                            self.cacheExtra.removeObject(forKey: k)
                        }
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func applyAppleIntelligenceOneClickFix() {
        self.objectWillChange.send()
        // 1. Apply user's selected region unlock mode (defaults to full US LL + LL/A + Axxxx; respects LL-only mode if selected)
        self.applyRegionUnlock(mode: self.currentRegionUnlockMode)
        // 2. Clear conflicting InternalInstall / InternalBuild / SiriHub / non-native AdvAI CacheExtra flags
        self.mgPullKeys([MGKey.intInstall, MGKey.intBuild, MGKey.siriHub] + MGKey.advAppIntellKeys)
        // 3. Unlock Mainland China green-tea / not-green-tea slots if originally restricted, and heal accidental SiriHub / AdvAI toggles
        if case .success((let layout, var data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
            let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
            let origFlags = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig)
            let ogRegion = (self.originalCacheExtraValue(forKey: MGKey.regionCode) as? String) ?? ""
            if ogRegion == "CH" || ogRegion == "ZA" || origFlags?.greenTea == true || data[layout.greenTeaOffset] == 1 {
                data[layout.greenTeaOffset] = 0
                data[layout.notGreenTeaOffset] = 1
            }
            if let siriHubSlot = layout.featureSlotIndices[MGKey.siriHub],
               layout.validateSingleBooleanSlot(siriHubSlot, in: data),
               data[siriHubSlot * 8] == 1 {
                let origSiriHub = MGCacheDataCoordinator.shared.originalSlotValue(forKey: MGKey.siriHub, layout: layout, savedOriginalDict: savedOrig) ?? false
                if !origSiriHub {
                    data[siriHubSlot * 8] = 0
                    for k in [MGKey.onDeviceSiri, MGKey.modelPruning] {
                        if let idx = layout.featureSlotIndices[k], layout.validateSingleBooleanSlot(idx, in: data) {
                            let origV = MGCacheDataCoordinator.shared.originalSlotValue(forKey: k, layout: layout, savedOriginalDict: savedOrig) ?? false
                            data[idx * 8] = origV ? 1 : 0
                        }
                    }
                }
            }
            // Heal non-native Personal Translator / Audio Intelligence slots while preserving native Audio Intelligence (1) on iPhone 18 Pro series
            if !isAdvAppleIntellHD() {
                for key in MGKey.advAppIntellKeys {
                    if let slotIdx = layout.featureSlotIndices[key],
                       layout.validateSingleBooleanSlot(slotIdx, in: data) {
                        let nativeVal = isAdvAISlotNativeTrue(key, layout: layout, savedOrig: savedOrig)
                        data[slotIdx * 8] = nativeVal ? 1 : 0
                    }
                    self.cacheExtra.removeObject(forKey: key)
                }
            }
            // 4. For non-native AI hardware, enable AI keys in both CacheExtra & CacheData slots
            if !isAppleIntellHD() {
                for key in MGKey.appIntellAllKeys {
                    self.cacheExtra[key] = 1
                    if let slotIdx = layout.featureSlotIndices[key], layout.validateSingleBooleanSlot(slotIdx, in: data) {
                        data[slotIdx * 8] = 1
                    }
                }
            }
            let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
            testDict["CacheData"] = data
            if case .success = layout.validatePlist(testDict) {
                self.mgCurrentDict["CacheData"] = data
            }
        } else if !isAppleIntellHD() {
            for key in MGKey.appIntellAllKeys {
                self.cacheExtra[key] = 1
            }
        }
    }

    func isAdvAppleIntellStagedOrActive() -> Bool {
        return isAdvAppleIntellConflictActive()
    }

    func cacheResolutionFailureReason() -> String? {
        switch MGCacheDataCoordinator.shared.resolveValidated(for: mgCurrentDict) {
        case .success:
            return nil
        case .failure(let err):
            return err.localizedDescription
        }
    }

    func mgChinaRestrictionCacheBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) else {
                    return false
                }
                return data[layout.greenTeaOffset] == 0 && data[layout.notGreenTeaOffset] == 1
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict) {
                case .failure(let err):
                    print("[!] (mg-cache) menolak modifikasi green-tea: \(err.localizedDescription)")
                    Alertinator.shared.alert(title: "Resolusi dinamis gagal, modifikasi ditolak!", body: err.localizedDescription)
                case .success((let layout, var data)):
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    if enabled {
                        data[layout.greenTeaOffset] = 0
                        data[layout.notGreenTeaOffset] = 1
                    } else {
                        if let orig = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig),
                           !(orig.greenTea == false && orig.notGreenTea == true) {
                            data[layout.greenTeaOffset] = orig.greenTea ? 1 : 0
                            data[layout.notGreenTeaOffset] = orig.notGreenTea ? 1 : 0
                        } else {
                            data[layout.greenTeaOffset] = 1
                            data[layout.notGreenTeaOffset] = 0
                        }
                    }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict) {
                    case .failure(let err):
                        print("[!] (mg-cache) self-check pasca-modifikasi gagal, menolak modifikasi: \(err.localizedDescription)")
                        Alertinator.shared.alert(title: "Validasi data cache gagal, modifikasi ditolak!", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        self.mgCurrentDict["CacheData"] = data
                    }
                }
            }
        )
    }

    func mgWapiWifiBinding() -> Binding<Bool> {
        return Binding<Bool>(
            get: {
                guard case .success((let layout, let data)) = MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict, checkWapiSlot: true),
                      let wOff = layout.wapiOffset else {
                    return false
                }
                return data[wOff] == 0
            },
            set: { enabled in
                switch MGCacheDataCoordinator.shared.resolveValidated(for: self.mgCurrentDict, checkWapiSlot: true) {
                case .failure(let err):
                    print("[!] (mg-cache) menolak modifikasi wapi: \(err.localizedDescription)")
                    Alertinator.shared.alert(title: "Resolusi dinamis gagal, modifikasi ditolak!", body: err.localizedDescription)
                case .success((let layout, var data)):
                    guard let wOff = layout.wapiOffset else {
                        Alertinator.shared.alert(title: "Resolusi dinamis gagal, modifikasi ditolak!", body: "Pustaka sistem saat ini tidak dapat menyelesaikan offset slot wapi secara unik.")
                        return
                    }
                    let savedOrig = NSDictionary(contentsOf: MGURL.savedGestaltURL)
                    if enabled {
                        data[wOff] = 0
                    } else {
                        if let orig = MGCacheDataCoordinator.shared.originalFlags(for: layout, savedOriginalDict: savedOrig),
                           let origWapi = orig.wapi,
                           origWapi == true {
                            data[wOff] = 1
                        } else {
                            data[wOff] = 1
                        }
                    }

                    let testDict = NSMutableDictionary(dictionary: self.mgCurrentDict)
                    testDict["CacheData"] = data
                    switch layout.validatePlist(testDict, checkWapiSlot: true) {
                    case .failure(let err):
                        print("[!] (mg-cache) self-check pasca-modifikasi gagal, menolak modifikasi: \(err.localizedDescription)")
                        Alertinator.shared.alert(title: "Validasi data cache gagal, modifikasi ditolak!", body: err.localizedDescription)
                    case .success:
                        self.objectWillChange.send()
                        self.mgCurrentDict["CacheData"] = data
                        if enabled {
                            Alertinator.shared.alert(title: "Pemberitahuan Penting WLAN menjadi Wi-Fi", body: MGMsg.wapiToWifi)
                        }
                    }
                }
            }
        )
    }
    
    // MARK: particular non-binded modifications
    // Disabled permanently by anti-bootloop security audit (SEC-M3-01): blind regex CacheData slicing causes soft-bricks.
    func mgSetiPadOS(enable: Bool) -> Bool {
        print("[!] (mg) blocked unsafe mgSetiPadOS regex CacheData mutation")
        return false
    }
}
