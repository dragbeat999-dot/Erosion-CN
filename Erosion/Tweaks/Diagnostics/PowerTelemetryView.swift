//
//  PowerTelemetryView.swift
//  Erosion
//
//  [Experimental / Fitur Uji] Read-only hardware battery health (raw mAh, cycle count,
//  voltage/amperage/wattage, cell temperature) & SoC thermal throttling telemetry
//  via APFS clonefile() snapshot of systemgroup.com.apple.powerlog.
//

import SwiftUI
import SQLite3

struct BatteryTelemetrySample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let levelPercent: Double?
    let rawMaxCapacitymAh: Int?
    let nominalCapacitymAh: Int?
    let designCapacitymAh: Int?
    let cycleCount: Int?
    let voltagemV: Int?
    let amperagemA: Int?
    let temperatureCelsius: Double?
    let isCharging: Bool?

    var computedPowerWatts: Double? {
        guard let v = voltagemV, let a = amperagemA else { return nil }
        return (Double(v) * Double(a)) / 1_000_000.0
    }

    var trueHealthPercent: Double? {
        guard let raw = rawMaxCapacitymAh, let design = designCapacitymAh, design > 0 else { return nil }
        return (Double(raw) / Double(design)) * 100.0
    }
}

struct ThermalTelemetryEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let levelCode: Int
    let summary: String
}

struct PowerTelemetryView: View {
    @State private var isLoading = false
    @State private var statusBanner: String = "Tekan tombol segarkan di kanan atas untuk membaca telemetri snapshot Powerlog tingkat bawah"
    @State private var powerlogAccessible = false
    @State private var latestBattery: BatteryTelemetrySample?
    @State private var recentBatterySamples: [BatteryTelemetrySample] = []
    @State private var thermalEvents: [ThermalTelemetryEvent] = []
    @State private var liveThermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState

    private static let powerlogDir = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.powerlog/Library/BatteryLife"
    private static let powerlogDBPath = "/private/var/containers/Shared/SystemGroup/systemgroup.com.apple.powerlog/Library/BatteryLife/CurrentPowerlog.PLSQL"
    private static let telemetryQueue = DispatchQueue(label: "com.erosion.telemetry.powerlog", qos: .userInitiated)

    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "flask.fill")
                        .foregroundStyle(Color.orange)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fitur Uji · Snapshot Telemetri Perangkat Keras Read-Only Murni")
                            .font(.subheadline.weight(.semibold))
                        Text("Melalui APFS clonefile() copy-on-write, CurrentPowerlog.PLSQL dikloning secara instan ke direktori sementara aplikasi ini lalu diurai secara read-only, tanpa penulisan fisik apa pun, sama sekali tidak memblokir daemon powerlogHelperd sistem (catatan: sebagian firmware iOS 26 membatasi penerbitan token sandbox Powerlog tingkat sistem, iOS 27 di perangkat asli mendukung pembacaan lengkap).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }

            Section {
                HStack {
                    Text("Status Termal Chip Real-time Saat Ini (ThermalState)")
                    Spacer()
                    Text(thermalStateLabel(liveThermalState))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(thermalStateColor(liveThermalState))
                }
                HStack {
                    Text("Status Snapshot Basis Data Powerlog")
                    Spacer()
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(powerlogAccessible ? "✅ Snapshot read-only ter-mount" : "Tidak ter-mount / terbatas")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(powerlogAccessible ? Color.green : Color.secondary)
                    }
                }
                Text(statusBanner)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                HeaderLabel("Kontrol Termal Chip Real-time dan Status Sumber Data", symbol: "thermometer.medium")
            }

            if let latest = latestBattery {
                Section {
                    if let health = latest.trueHealthPercent {
                        metricRow(
                            title: "Kesehatan Baterai Fisik Sesungguhnya",
                            value: String(format: "%.2f%%", health),
                            accent: health >= 85 ? .green : (health >= 78 ? .orange : .red)
                        )
                    }
                    if let raw = latest.rawMaxCapacitymAh {
                        metricRow(title: "Kapasitas Maksimum Fisik Sesungguhnya (RawMaxCapacity)", value: "\(raw) mAh")
                    }
                    if let nom = latest.nominalCapacitymAh {
                        metricRow(title: "Kapasitas Isi Penuh Nominal Sistem (NominalCapacity)", value: "\(nom) mAh")
                    }
                    if let des = latest.designCapacitymAh {
                        metricRow(title: "Kapasitas Desain Pabrik (DesignCapacity)", value: "\(des) mAh")
                    }
                    if let cyc = latest.cycleCount {
                        metricRow(title: "Jumlah Siklus Lengkap Presisi (CycleCount)", value: "\(cyc) kali")
                    }
                    if let temp = latest.temperatureCelsius {
                        metricRow(
                            title: "Suhu Sensor Fisik Sel Baterai",
                            value: String(format: "%.1f °C", temp),
                            accent: temp >= 40 ? .red : (temp >= 36 ? .orange : .primary)
                        )
                    }
                    if let v = latest.voltagemV {
                        metricRow(title: "Tegangan Sel Real-time (Voltage)", value: "\(v) mV (\(String(format: "%.2f V", Double(v) / 1000.0)))")
                    }
                    if let a = latest.amperagemA {
                        let signHint = a >= 0 ? "Input Pengisian" : "Konsumsi Pengosongan"
                        metricRow(title: "Arus Pengisian/Pengosongan Sesaat (\(signHint))", value: "\(a) mA")
                    }
                    if let watts = latest.computedPowerWatts {
                        metricRow(
                            title: "Daya Pengisian/Pengosongan Real-time Perangkat",
                            value: String(format: "%.2f W", abs(watts)),
                            accent: watts >= 0 ? .green : .blue
                        )
                    }
                    metricRow(title: "Waktu Pengambilan Sampel Snapshot Terbaru", value: formatDate(latest.timestamp))
                } header: {
                    HeaderLabel("Metrik Lengkap Sel Baterai Fisik [Uji]", symbol: "battery.100percent.bolt")
                } footer: {
                    Text("Petunjuk: Persentase yang ditampilkan di \"Pengaturan -> Kesehatan Baterai\" sistem telah dimodifikasi oleh algoritma kalibrasi penghalusan, sedangkan AppleRawMaxCapacity mencerminkan kapasitas penuh fisik sesungguhnya yang diukur oleh chip pengukur daya PMU.")
                }
            }

            if !thermalEvents.isEmpty {
                Section {
                    ForEach(thermalEvents.prefix(12)) { ev in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.summary)
                                    .font(.subheadline.weight(.medium))
                                Text(formatDate(ev.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Level \(ev.levelCode)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(ev.levelCode >= 20 ? Color.orange : Color.secondary)
                        }
                    }
                } header: {
                    HeaderLabel("Catatan Termal Chip dan Throttling Terbaru [Uji]", symbol: "flame")
                }
            }

            if !recentBatterySamples.isEmpty {
                Section {
                    ForEach(recentBatterySamples.prefix(15)) { sample in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                let lvlText = sample.levelPercent.map { String(format: "%.0f%%", $0) } ?? "--%"
                                let tempText = sample.temperatureCelsius.map { String(format: "%.1f°C", $0) } ?? "--°C"
                                Text("Baterai \(lvlText) · Suhu \(tempText)")
                                    .font(.subheadline)
                                Text(formatDate(sample.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let watts = sample.computedPowerWatts {
                                Text(String(format: "%@%.2f W", watts >= 0 ? "+" : "-", abs(watts)))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(watts >= 0 ? Color.green : Color.secondary)
                            }
                        }
                    }
                } header: {
                    HeaderLabel("Aliran Pengambilan Sampel Baterai Terbaru (15 Terakhir)", symbol: "chart.xyaxis.line")
                }
            }
        }
        .navigationTitle("Telemetri Baterai dan Termal [Uji]")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if latestBattery != nil {
                    Button {
                        exportJSONReport()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    refreshTelemetry()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .onAppear {
            liveThermalState = ProcessInfo.processInfo.thermalState
            if latestBattery == nil && !isLoading {
                refreshTelemetry()
            }
        }
    }

    @ViewBuilder
    private func metricRow(title: String, value: String, accent: Color = .primary) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(accent)
        }
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Normal (Nominal · Tanpa Throttling)"
        case .fair: return "Hangat (Fair · Termal Ringan)"
        case .serious: return "Panas dan Throttling (Serious · Frame Terkunci/Throttling)"
        case .critical: return "Overheat Parah (Critical · Batas Frekuensi dan Kecerahan Paksa)"
        @unknown default: return "Status Tidak Diketahui"
        }
    }

    private func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .secondary
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd HH:mm:ss"
        return fmt.string(from: date)
    }

    private func refreshTelemetry() {
        isLoading = true
        statusBanner = "Sedang me-mount snapshot read-only CurrentPowerlog.PLSQL..."
        liveThermalState = ProcessInfo.processInfo.thermalState
        Self.telemetryQueue.async {
            let wasActive = wq.hasActiveAccess(path: Self.powerlogDir)
            let grant = wq.grantAccess(path: Self.powerlogDir, requireWrite: false)
            defer {
                if !wasActive {
                    wq.releaseAccess(path: Self.powerlogDir)
                }
            }

            guard grant.0 && fm.isReadableFile(atPath: Self.powerlogDBPath) else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.powerlogAccessible = false
                    self.statusBanner = "Firmware saat ini tidak mengizinkan token ekstensi read-only systemgroup.com.apple.powerlog (\(grant.2)). Status termal chip real-time di atas tetap dapat dipantau dengan normal."
                }
                return
            }

            do {
                let parsed = try SQLiteSnapshotHelper.withClonedDatabase(at: Self.powerlogDBPath) { db in
                    let batSamples = Self.queryBatterySamples(db: db)
                    let thermals = Self.queryThermalEvents(db: db)
                    return (batSamples, thermals)
                }
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.powerlogAccessible = true
                    self.recentBatterySamples = parsed.0
                    self.latestBattery = parsed.0.first
                    self.thermalEvents = parsed.1
                    if parsed.0.isEmpty {
                        self.statusBanner = "Snapshot Powerlog berhasil dibuka, tetapi tidak ada catatan tabel pengambilan sampel baterai terbaru yang ditemukan."
                    } else {
                        self.statusBanner = "Berhasil mengurai \(parsed.0.count) catatan baterai terbaru dan \(parsed.1.count) catatan termal melalui snapshot tanpa lock APFS clonefile."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.powerlogAccessible = false
                    self.statusBanner = "Anomali penguraian snapshot Powerlog: \(error.localizedDescription)"
                }
            }
        }
    }

    private static func queryBatterySamples(db: OpaquePointer) -> [BatteryTelemetrySample] {
        let tables = SQLiteSnapshotHelper.allTables(in: db)
        let candidates = [
            "PLBatteryAgent_EventBackward_Battery",
            "PLBatteryAgent_EventForward_Battery",
            "PLBatteryAgent_EventBackward_BatteryUI"
        ]
        guard let tableName = candidates.first(where: { tables.contains($0) }) ?? tables.first(where: { $0.contains("PLBatteryAgent") && $0.hasSuffix("_Battery") }) else {
            return []
        }

        let cols = SQLiteSnapshotHelper.columnNames(in: tableName, db: db)
        guard cols.contains("timestamp") else { return [] }

        func pick(_ names: [String]) -> String {
            for n in names where cols.contains(n) {
                return "\"\(n)\""
            }
            return "NULL"
        }

        let sql = """
        SELECT timestamp,
               \(pick(["Level", "CurrentCapacity"])),
               \(pick(["AppleRawMaxCapacity", "RawMaxCapacity", "MaxCapacity"])),
               \(pick(["NominalChargeCapacity", "MaxCapacity"])),
               \(pick(["DesignCapacity"])),
               \(pick(["CycleCount"])),
               \(pick(["Voltage"])),
               \(pick(["InstantAmperage", "Amperage"])),
               \(pick(["Temperature"])),
               \(pick(["IsCharging"]))
        FROM "\(tableName)"
        ORDER BY timestamp DESC
        LIMIT 25;
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let validStmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(validStmt) }

        var samples: [BatteryTelemetrySample] = []
        while sqlite3_step(validStmt) == SQLITE_ROW {
            guard let ts = SQLiteSnapshotHelper.doubleCol(validStmt, 0) else { continue }
            let rawTemp = SQLiteSnapshotHelper.doubleCol(validStmt, 8)
            let normalizedTemp: Double? = rawTemp.map { abs($0) > 120.0 ? ($0 / 100.0) : $0 }
            let chargingInt = SQLiteSnapshotHelper.intCol(validStmt, 9)

            samples.append(
                BatteryTelemetrySample(
                    id: UUID(),
                    timestamp: Date(timeIntervalSince1970: ts),
                    levelPercent: SQLiteSnapshotHelper.doubleCol(validStmt, 1),
                    rawMaxCapacitymAh: SQLiteSnapshotHelper.intCol(validStmt, 2),
                    nominalCapacitymAh: SQLiteSnapshotHelper.intCol(validStmt, 3),
                    designCapacitymAh: SQLiteSnapshotHelper.intCol(validStmt, 4),
                    cycleCount: SQLiteSnapshotHelper.intCol(validStmt, 5),
                    voltagemV: SQLiteSnapshotHelper.intCol(validStmt, 6),
                    amperagemA: SQLiteSnapshotHelper.intCol(validStmt, 7),
                    temperatureCelsius: normalizedTemp,
                    isCharging: chargingInt.map { $0 != 0 }
                )
            )
        }
        return samples
    }

    private static func queryThermalEvents(db: OpaquePointer) -> [ThermalTelemetryEvent] {
        let tables = SQLiteSnapshotHelper.allTables(in: db)
        let candidates = [
            "PLThermalAgent_EventPoint_ThermalStatus",
            "PLXPCAgent_EventPoint_ThermalLevel",
            "PLThermalMonitorAgent_EventPoint_ThermalLevel"
        ]
        guard let tableName = candidates.first(where: { tables.contains($0) }) ?? tables.first(where: { $0.localizedCaseInsensitiveContains("Thermal") && $0.contains("Event") }) else {
            return []
        }

        let cols = SQLiteSnapshotHelper.columnNames(in: tableName, db: db)
        guard cols.contains("timestamp") else { return [] }
        let levelCol = ["ThermalLevel", "thermalLevel", "Level", "State"].first(where: { cols.contains($0) })
        guard let levelCol else { return [] }

        let sql = "SELECT timestamp, \"\(levelCol)\" FROM \"\(tableName)\" ORDER BY timestamp DESC LIMIT 20;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let validStmt = stmt else {
            return []
        }
        defer { sqlite3_finalize(validStmt) }

        var out: [ThermalTelemetryEvent] = []
        while sqlite3_step(validStmt) == SQLITE_ROW {
            guard let ts = SQLiteSnapshotHelper.doubleCol(validStmt, 0),
                  let lvl = SQLiteSnapshotHelper.intCol(validStmt, 1) else { continue }
            let desc: String
            switch lvl {
            case ..<1: desc = "Disipasi panas kembali normal (Nominal)"
            case 1...10: desc = "Kontrol termal ringan aktif (Light / Fair)"
            case 11...20: desc = "Throttling dan batas frame sedang (Moderate / Serious)"
            case 21...30: desc = "Pembatasan performa dan penurunan kecerahan berat (Heavy)"
            default: desc = "Ambang perlindungan overheat terpicu (Critical)"
            }
            out.append(ThermalTelemetryEvent(id: UUID(), timestamp: Date(timeIntervalSince1970: ts), levelCode: lvl, summary: desc))
        }
        return out
    }

    private func exportJSONReport() {
        struct ExportPayload: Codable {
            let exportedAt: Date
            let deviceModel: String
            let osBuild: String
            let latestBattery: BatteryTelemetrySample?
            let recentSamples: [BatteryTelemetrySample]
            let thermalEvents: [ThermalTelemetryEvent]
        }
        let payload = ExportPayload(
            exportedAt: Date(),
            deviceModel: machineName(),
            osBuild: buildNumber(),
            latestBattery: latestBattery,
            recentSamples: recentBatterySamples,
            thermalEvents: thermalEvents
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(payload) {
            let outURL = fm.temporaryDirectory.appendingPathComponent("Erosion_PowerTelemetry_\(Int(Date().timeIntervalSince1970)).json")
            try? data.write(to: outURL, options: .atomic)
            presentShareSheet(with: outURL)
        }
    }
}
