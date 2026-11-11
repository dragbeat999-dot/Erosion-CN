//
//  CustomKeyView.swift
//  Erosion
//
//  Created by lunginspector on 9/8/26.
//

import SwiftUI

enum MGCustomValueType: String, Codable, CaseIterable {
    case int, string, bool
    
    var label: String {
        switch self {
        case .int: return "Bilangan Bulat (Int)"
        case .string: return "String (Teks)"
        case .bool: return "Boolean (Bool)"
        }
    }
}

struct MGCustomKey: Identifiable, Codable, Equatable {
    var id: String { key }
    let key: String
    var valueType: MGCustomValueType
    var value: Int
    var stringValue: String
    var boolValue: Bool
    var isOn: Bool
    
    init(key: String, valueType: MGCustomValueType = .int, value: Int = 1, stringValue: String = "", boolValue: Bool = true, isOn: Bool = true) {
        self.key = key
        self.valueType = valueType
        self.value = value
        self.stringValue = stringValue
        self.boolValue = boolValue
        self.isOn = isOn
    }
    
    enum CodingKeys: String, CodingKey {
        case key, valueType, value, stringValue, boolValue, isOn
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.key = try container.decode(String.self, forKey: .key)
        self.valueType = (try? container.decode(MGCustomValueType.self, forKey: .valueType)) ?? .int
        let decodedInt = (try? container.decode(Int.self, forKey: .value)) ?? 0
        self.value = decodedInt
        self.stringValue = (try? container.decode(String.self, forKey: .stringValue)) ?? "\(decodedInt)"
        self.boolValue = (try? container.decode(Bool.self, forKey: .boolValue)) ?? (decodedInt != 0)
        self.isOn = (try? container.decode(Bool.self, forKey: .isOn)) ?? false
    }
    
    var plistValue: Any {
        switch valueType {
        case .int: return value
        case .string: return stringValue
        case .bool: return boolValue
        }
    }
    
    var displayValue: String {
        switch valueType {
        case .int: return "\(value)"
        case .string: return "\"\(stringValue)\""
        case .bool: return boolValue ? "true" : "false"
        }
    }
}

struct CustomKeyView: View {
    @AppStorage("mgCustKeyArray") private var customKeys = [MGCustomKey]()
    @State private var cstkKey = ""
    @State private var cstkType: MGCustomValueType = .int
    @State private var cstkValue: Int? = 1
    @State private var cstkStringValue = ""
    @State private var cstkBoolValue = true
    @State private var itemToEdit: MGCustomKey?
    
    var body: some View {
        List {
            Section {
                TextField("Nama Kunci (mis. 97JDvERpVwO+GHtthIh7hA)", text: $cstkKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Tipe Nilai Kunci", selection: $cstkType) {
                    ForEach(MGCustomValueType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                switch cstkType {
                case .int:
                    TextField("Nilai Bilangan Bulat (mis. 1)", value: $cstkValue, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                case .string:
                    TextField("Nilai String (mis. A3473)", text: $cstkStringValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .bool:
                    Toggle(cstkBoolValue ? "Aktif (True)" : "Nonaktif (False)", isOn: $cstkBoolValue)
                }
                Button("Tambah Kunci Kustom") {
                    let trimmedKey = cstkKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedKey.isEmpty || (cstkType == .int && cstkValue == nil) {
                        Alertinator.shared.alert(title: "Nama atau nilai kunci tidak valid!", body: "Harap isi nama kunci dan nilai yang sesuai secara lengkap sebelum mencoba lagi.")
                    } else if let blockedReason = mgIsDangerousCacheExtraKey(trimmedKey) {
                        Alertinator.shared.alert(title: "Nama kunci berisiko tinggi atau bukan cache telah diblokir!", body: "\(blockedReason)\n\nUntuk mencegah kegagalan validasi boot sistem atau anomali RF, pagar pengaman melarang injeksi manual kunci ini ke CacheExtra.")
                    } else if customKeys.contains(where: { $0.key == trimmedKey }) {
                        Alertinator.shared.alert(title: "Nama kunci ini sudah ada!", body: "Silakan klik nama kunci yang sesuai di daftar di bawah untuk mengubahnya.")
                    } else {
                        customKeys.append(
                            MGCustomKey(
                                key: trimmedKey,
                                valueType: cstkType,
                                value: cstkValue ?? 0,
                                stringValue: cstkStringValue,
                                boolValue: cstkBoolValue,
                                isOn: true
                            )
                        )
                        cstkKey = ""
                        cstkStringValue = ""
                    }
                }
            } header: {
                HeaderLabel("Tambah Kunci Kustom", symbol: "plus")
            }
            
            Section {
                ForEach(customKeys) { item in
                    Toggle(isOn: mgIsOnBinding(for: item)) {
                        Button {
                            itemToEdit = item
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.key)
                                    .foregroundStyle(Color(.label))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Text("\(item.valueType.label)：\(item.displayValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { indexSet in
                    customKeys.remove(atOffsets: indexSet)
                }
            } header: {
                if !customKeys.isEmpty {
                    HeaderLabel("Daftar yang Ditambahkan (Geser Kiri untuk Hapus, Ketuk untuk Edit)", symbol: "list.bullet")
                }
            }
        }
        .navigationTitle("Nilai Kunci Kustom")
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $itemToEdit) { item in
            EditorPane(item: item)
                .presentationDetents([.fraction(0.42)])
        }
    }
    
    // i hate this as a solution, but it seems like there's a long-standing bug in swiftui where the whole app will crash if i drop all items from an array that uses a direct binding with toggles. really stupid, i know, but that's sorta the way things are. gotta love swiftui...
    // -lunginspector 8/6/26
    private func mgIsOnBinding(for item: MGCustomKey) -> Binding<Bool> {
        Binding(
            get: { customKeys.first(where: { $0.id == item.id })?.isOn ?? false },
            set: { newValue in
                if let index = customKeys.firstIndex(where: { $0.id == item.id }) {
                    customKeys[index].isOn = newValue
                }
            }
        )
    }
    
    private struct EditorPane: View {
        @State var item: MGCustomKey
        @Environment(\.dismiss) var dismiss
        @AppStorage("mgCustKeyArray") var customKeys: [MGCustomKey] = []
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 12) {
                    Text(item.key)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .modifier(TextFieldBackground())
                    Picker("Tipe Nilai Kunci", selection: $item.valueType) {
                        ForEach(MGCustomValueType.allCases, id: \.self) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch item.valueType {
                    case .int:
                        TextField("Nilai Bilangan Bulat", value: $item.value, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .modifier(TextFieldBackground())
                    case .string:
                        TextField("Nilai String", text: $item.stringValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .modifier(TextFieldBackground())
                    case .bool:
                        Toggle(item.boolValue ? "Aktif (True)" : "Nonaktif (False)", isOn: $item.boolValue)
                            .modifier(TextFieldBackground())
                    }
                }
                .padding(.horizontal)
                .navigationTitle("Ubah Kunci Kustom")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Tutup", systemImage: "xmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .adaptiveConfirm) {
                            if let index = customKeys.firstIndex(where: { $0.key == item.key }) {
                                customKeys[index] = item
                            }
                            dismiss()
                        } label: {
                            Label("Konfirmasi", systemImage: "checkmark")
                                .labelStyle(.iconOnly)
                        }
                    }
                }
            }
        }
    }
}
