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
                    Label(L10n.general, systemImage: "gear")
                }

            captureTab
                .tabItem {
                    Label(L10n.captureSettings, systemImage: "camera")
                }

            if let presetStore {
                BrandPresetSettingsView(store: presetStore)
                    .tabItem {
                        Label(L10n.brand, systemImage: "paintpalette")
                    }
            }

            permissionTab
                .tabItem {
                    Label(L10n.permissions, systemImage: "lock.shield")
                }
        }
        .frame(width: 560, height: 400)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            LabeledContent(L10n.saveDirectory) {
                HStack {
                    Text(settings.saveDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 200, alignment: .leading)

                    Button(L10n.change) {
                        chooseSaveDirectory()
                    }
                }
            }

            Picker(L10n.fileName, selection: Bindable(settings).fileNamePattern) {
                ForEach(FileNamePattern.allCases) { pattern in
                    Text(pattern.label).tag(pattern)
                }
            }

            Picker(L10n.imageFormat, selection: Bindable(settings).imageFormat) {
                ForEach(ImageFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }

            Divider()

            Toggle(L10n.launchAtLogin, isOn: Binding(
                get: { loginItemManager.isEnabled },
                set: { _ in loginItemManager.toggle() }
            ))
        }
        .padding()
    }

    // MARK: - Capture Tab

    private var captureTab: some View {
        Form {
            Toggle(L10n.retinaCapture, isOn: Bindable(settings).captureRetina)

            Divider()

            Section("Quick Access Overlay") {
                Picker(L10n.overlayPosition, selection: Bindable(settings).overlayPosition) {
                    ForEach(OverlayPosition.allCases) { position in
                        Text(position.label).tag(position)
                    }
                }

                Stepper(
                    L10n.autoCloseSeconds(settings.overlayAutoCloseSeconds),
                    value: Bindable(settings).overlayAutoCloseSeconds,
                    in: 0...30,
                    step: 1
                )

                if settings.overlayAutoCloseSeconds == 0 {
                    Text(L10n.autoCloseDisabled)
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
                description: L10n.screenRecordingDesc,
                isGranted: permissionManager.hasScreenRecordingPermission,
                action: permissionManager.openScreenRecordingSettings
            )

            permissionRow(
                title: "Accessibility",
                description: L10n.accessibilityDesc,
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
                Label(L10n.granted, systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            } else {
                Button(L10n.openSystemSettings) {
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
