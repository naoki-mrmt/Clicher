import SwiftUI
import SharedModels

/// 背景設定パネル（Annotate エディタのサイドバー）
public struct BackgroundSettingsView: View {
    @Binding public var config: BackgroundConfig
    @Binding public var isEnabled: Bool

    @State private var bgType: BackgroundType = .solid
    @State private var solidColor: Color = Color(white: 0.95)
    @State private var gradientStart: Color = .pink
    @State private var gradientEnd: Color = .blue
    @State private var gradientAngle: Double = 135
    @State private var selectedPreset: SNSSizePreset?

    public init(config: Binding<BackgroundConfig>, isEnabled: Binding<Bool>) {
        _config = config
        _isEnabled = isEnabled
    }

    enum BackgroundType: CaseIterable {
        case solid, gradient

        var label: String {
            switch self {
            case .solid: L10n.bgTypeSolid
            case .gradient: L10n.bgTypeGradient
            }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 有効/無効トグル
            Toggle(L10n.addBackground, isOn: $isEnabled)
                .toggleStyle(.switch)

            if isEnabled {
                // 背景タイプ
                Picker(L10n.bgType, selection: $bgType) {
                    ForEach(BackgroundType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: bgType) { _, _ in updateConfig() }

                // 色設定
                switch bgType {
                case .solid:
                    ColorPicker(L10n.bgColor, selection: $solidColor)
                        .onChange(of: solidColor) { _, _ in updateConfig() }
                case .gradient:
                    ColorPicker(L10n.gradientStartColor, selection: $gradientStart)
                        .onChange(of: gradientStart) { _, _ in updateConfig() }
                    ColorPicker(L10n.gradientEndColor, selection: $gradientEnd)
                        .onChange(of: gradientEnd) { _, _ in updateConfig() }
                    HStack {
                        Text(L10n.angle)
                        Slider(value: $gradientAngle, in: 0...360)
                            .onChange(of: gradientAngle) { _, _ in updateConfig() }
                        Text("\(Int(gradientAngle))°")
                            .monospacedDigit()
                            .frame(width: 35)
                    }
                }

                Divider()

                // パディング
                HStack {
                    Text(L10n.padding)
                    Slider(value: $config.padding, in: 0...100)
                    Text("\(Int(config.padding))")
                        .monospacedDigit()
                        .frame(width: 30)
                }

                // 角丸
                HStack {
                    Text(L10n.cornerRadius)
                    Slider(value: $config.cornerRadius, in: 0...40)
                    Text("\(Int(config.cornerRadius))")
                        .monospacedDigit()
                        .frame(width: 30)
                }

                // シャドウ
                HStack {
                    Text(L10n.shadow)
                    Slider(value: $config.shadowRadius, in: 0...30)
                    Text("\(Int(config.shadowRadius))")
                        .monospacedDigit()
                        .frame(width: 30)
                }

                Divider()

                // SNS プリセット
                Text(L10n.snsPresets)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(SNSSizePreset.allCases) { preset in
                    Button {
                        selectedPreset = preset
                        config.targetSize = preset.size
                    } label: {
                        HStack {
                            Text(preset.label)
                                .font(.caption)
                            Spacer()
                            if selectedPreset == preset {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button(L10n.resetSize) {
                    selectedPreset = nil
                    config.targetSize = nil
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(width: 200)
    }

    private func updateConfig() {
        switch bgType {
        case .solid:
            config.style = .solidColor(NSColor(solidColor).cgColor)
        case .gradient:
            config.style = .gradient(
                startColor: NSColor(gradientStart).cgColor,
                endColor: NSColor(gradientEnd).cgColor,
                angle: gradientAngle
            )
        }
    }
}
