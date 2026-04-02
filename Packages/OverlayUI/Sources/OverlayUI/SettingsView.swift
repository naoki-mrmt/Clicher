import SwiftUI
import SharedModels
import Utilities

/// 設定画面
public struct SettingsView: View {
    public let settings: AppSettings
    public let permissionManager: PermissionManager
    public let loginItemManager: LoginItemManager
    public let presetStore: BrandPresetStore?

    public init(
        settings: AppSettings,
        permissionManager: PermissionManager,
        loginItemManager: LoginItemManager,
        presetStore: BrandPresetStore? = nil
    ) {
        self.settings = settings
        self.permissionManager = permissionManager
        self.loginItemManager = loginItemManager
        self.presetStore = presetStore
    }

    public var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            captureTab
                .tabItem {
                    Label("キャプチャ", systemImage: "camera")
                }

            if let presetStore {
                BrandPresetSettingsView(store: presetStore)
                    .tabItem {
                        Label("ブランド", systemImage: "paintpalette")
                    }
            }

            permissionTab
                .tabItem {
                    Label("権限", systemImage: "lock.shield")
                }
        }
        .frame(width: 560, height: 400)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            // 保存先
            LabeledContent("保存先") {
                HStack {
                    Text(settings.saveDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .leading)

                    Button("変更...") {
                        chooseSaveDirectory()
                    }
                }
            }

            // ファイル名
            Picker("ファイル名", selection: Bindable(settings).fileNamePattern) {
                ForEach(FileNamePattern.allCases) { pattern in
                    Text(pattern.label).tag(pattern)
                }
            }

            // 画像フォーマット
            Picker("画像形式", selection: Bindable(settings).imageFormat) {
                ForEach(ImageFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }

            Divider()

            // ログイン時起動
            Toggle("ログイン時に起動", isOn: Binding(
                get: { loginItemManager.isEnabled },
                set: { _ in loginItemManager.toggle() }
            ))
        }
        .padding()
    }

    // MARK: - Capture Tab

    private var captureTab: some View {
        Form {
            // Retina
            Toggle("Retina 解像度でキャプチャ (2x)", isOn: Bindable(settings).captureRetina)

            Divider()

            // Overlay
            Section("Quick Access Overlay") {
                Picker("表示位置", selection: Bindable(settings).overlayPosition) {
                    ForEach(OverlayPosition.allCases) { position in
                        Text(position.label).tag(position)
                    }
                }

                Stepper(
                    "自動クローズ: \(settings.overlayAutoCloseSeconds)秒",
                    value: Bindable(settings).overlayAutoCloseSeconds,
                    in: 0...30,
                    step: 1
                )

                if settings.overlayAutoCloseSeconds == 0 {
                    Text("自動クローズは無効です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }

    // MARK: - Permission Tab

    private var permissionTab: some View {
        Form {
            permissionRow(
                title: "Screen Recording",
                description: "画面のキャプチャに必要",
                isGranted: permissionManager.hasScreenRecordingPermission,
                action: permissionManager.openScreenRecordingSettings
            )

            permissionRow(
                title: "Accessibility",
                description: "グローバルホットキー (⌘⇧A) に必要",
                isGranted: permissionManager.hasAccessibilityPermission,
                action: permissionManager.openAccessibilitySettings
            )
        }
        .padding()
        .onAppear {
            permissionManager.checkAll()
        }
    }

    private func permissionRow(
        title: String,
        description: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Label("許可済み", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Button("システム設定を開く") {
                    action()
                }
                .controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task { @MainActor in
                    settings.saveDirectory = url
                }
            }
        }
    }
}
