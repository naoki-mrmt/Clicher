import SwiftUI
import SharedModels
import Utilities

/// ブランドプリセット管理画面（設定タブ）
public struct BrandPresetSettingsView: View {
    let store: BrandPresetStore

    @State private var presets: [BrandPreset] = []
    @State private var selectedPreset: BrandPreset?
    @State private var isEditing = false
    @State private var errorMessage: String?

    public init(store: BrandPresetStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 機能説明ヘッダー
            featureDescription

            Divider()

            HSplitView {
                // プリセット一覧（左）
                presetList
                    .frame(minWidth: 180, maxWidth: 220)

                // 詳細/編集（右）
                if let preset = selectedPreset {
                    presetDetail(preset)
                } else {
                    emptyState
                }
            }
        }
        .onAppear { presets = store.loadAll() }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Feature Description

    private var featureDescription: some View {
        HStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.brandPresets)
                    .font(.headline)
                Text(L10n.brandDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text(L10n.selectOrAddPreset)
                .foregroundStyle(.secondary)

            Text(L10n.addPresetHint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(spacing: 0) {
            List(selection: Binding(
                get: { selectedPreset?.id },
                set: { id in selectedPreset = presets.first { $0.id == id } }
            )) {
                ForEach(presets) { preset in
                    HStack {
                        Circle()
                            .fill(Color(cgColor: preset.primaryColor.cgColor))
                            .frame(width: 12, height: 12)
                        Text(preset.name)
                            .lineLimit(1)
                        Spacer()
                        if preset.isDefault {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .tag(preset.id)
                }
            }

            Divider()

            // 追加/削除ボタン
            HStack {
                Button {
                    addPreset()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)

                Button {
                    if let preset = selectedPreset {
                        deletePreset(preset)
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.plain)
                .disabled(selectedPreset == nil)

                Spacer()

                // インポート
                Button {
                    importPreset()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .help("インポート")
            }
            .padding(6)
        }
    }

    // MARK: - Preset Detail

    private func presetDetail(_ preset: BrandPreset) -> some View {
        Form {
            Section("基本情報") {
                TextField("名前", text: binding(for: preset, keyPath: \.name))

                Toggle("デフォルトプリセット", isOn: binding(for: preset, keyPath: \.isDefault))
            }

            Section("カラー") {
                colorPickerRow("プライマリ", preset: preset, keyPath: \.primaryColor)
                colorPickerRow("セカンダリ", preset: preset, keyPath: \.secondaryColor)
                colorPickerRow("アクセント", preset: preset, keyPath: \.accentColor)
            }

            Section("ロゴ") {
                Picker("位置", selection: binding(for: preset, keyPath: \.logoPosition)) {
                    ForEach(LogoPosition.allCases) { pos in
                        Text(pos.label).tag(pos)
                    }
                }

                HStack {
                    Text("不透明度")
                    Slider(value: binding(for: preset, keyPath: \.logoOpacity), in: 0.1...1.0)
                    Text("\(Int(preset.logoOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }

            Section {
                HStack {
                    // エクスポート
                    Button("エクスポート") {
                        exportPreset(preset)
                    }

                    Spacer()

                    // 保存
                    Button("保存") {
                        savePreset(preset)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    private func colorPickerRow(_ label: String, preset: BrandPreset, keyPath: WritableKeyPath<BrandPreset, CodableColor>) -> some View {
        let colorBinding = Binding<Color>(
            get: {
                Color(cgColor: preset[keyPath: keyPath].cgColor)
            },
            set: { newColor in
                guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
                guard let components = NSColor(newColor).cgColor.components, components.count >= 3 else { return }
                presets[index][keyPath: keyPath] = CodableColor(
                    red: components[0],
                    green: components[1],
                    blue: components[2],
                    alpha: components.count >= 4 ? components[3] : 1.0
                )
                selectedPreset = presets[index]
            }
        )
        return ColorPicker(label, selection: colorBinding)
    }

    // MARK: - Actions

    private func addPreset() {
        let preset = BrandPreset(name: "新規プリセット \(presets.count + 1)")
        do {
            try store.save(preset)
            presets = store.loadAll()
            selectedPreset = preset
        } catch {
            errorMessage = "プリセットの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    private func deletePreset(_ preset: BrandPreset) {
        do {
            try store.delete(preset)
            presets = store.loadAll()
            selectedPreset = nil
        } catch {
            errorMessage = "プリセットの削除に失敗しました: \(error.localizedDescription)"
        }
    }

    private func savePreset(_ preset: BrandPreset) {
        do {
            try store.save(preset)
            presets = store.loadAll()
        } catch {
            errorMessage = "プリセットの保存に失敗しました: \(error.localizedDescription)"
        }
    }

    private func importPreset() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    let imported = try store.importFromClipreset(at: url)
                    presets = store.loadAll()
                    selectedPreset = imported
                } catch {
                    errorMessage = "インポートに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportPreset(_ preset: BrandPreset) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(preset.name).clipreset"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                do {
                    try store.exportToClipreset(preset, to: url)
                } catch {
                    errorMessage = "エクスポートに失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Binding Helpers

    private func binding<T>(for preset: BrandPreset, keyPath: WritableKeyPath<BrandPreset, T>) -> Binding<T> {
        Binding(
            get: { preset[keyPath: keyPath] },
            set: { newValue in
                guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
                presets[index][keyPath: keyPath] = newValue
                selectedPreset = presets[index]
            }
        )
    }
}
