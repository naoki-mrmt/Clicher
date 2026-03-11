import SwiftUI

/// 設定画面
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var permissionManager = PermissionManager()

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsTab(settings: settings)
            }
            Tab("Shortcuts", systemImage: "keyboard") {
                ShortcutsSettingsTab(settings: settings)
            }
            Tab("Capture", systemImage: "camera") {
                CaptureSettingsTab(settings: settings)
            }
            Tab("Permissions", systemImage: "lock.shield") {
                PermissionsSettingsTab(permissionManager: permissionManager)
            }
        }
        .frame(width: 500, height: 350)
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)

            Picker("Overlay Position", selection: $settings.overlayPosition) {
                ForEach(OverlayPosition.allCases) { position in
                    Text(position.displayName).tag(position)
                }
            }

            HStack {
                Text("Auto-close Delay:")
                Slider(
                    value: $settings.overlayAutoCloseDelay,
                    in: 2...15,
                    step: 1
                )
                Text(settings.overlayAutoCloseDelay, format: .number.precision(.fractionLength(0)))
                Text("sec")
            }

            Toggle("Show Overlay After Capture", isOn: $settings.showOverlayAfterCapture)
        }
        .padding()
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            LabeledContent("Area Capture") {
                Text(settings.areaCaptureHotkey.displayString)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(.rect(cornerRadius: 4))
            }

            LabeledContent("Window Capture") {
                Text(settings.windowCaptureHotkey.displayString)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(.rect(cornerRadius: 4))
            }

            LabeledContent("Fullscreen Capture") {
                Text(settings.fullscreenCaptureHotkey.displayString)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary)
                    .clipShape(.rect(cornerRadius: 4))
            }

            Text("Hotkey customization will be available in a future update.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

// MARK: - Capture

struct CaptureSettingsTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            LabeledContent("Save Location") {
                HStack {
                    Text(settings.defaultSaveDirectory.path())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose…") {
                        chooseSaveDirectory()
                    }
                }
            }

            Picker("File Naming", selection: $settings.fileNamePattern) {
                ForEach(FileNamePattern.allCases) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }

            Picker("Image Quality", selection: $settings.retinaScale) {
                ForEach(RetinaScale.allCases) { scale in
                    Text(scale.displayName).tag(scale)
                }
            }
        }
        .padding()
    }

    private func chooseSaveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.defaultSaveDirectory = url
        }
    }
}

// MARK: - Permissions

struct PermissionsSettingsTab: View {
    let permissionManager: PermissionManager

    var body: some View {
        Form {
            LabeledContent("Screen Recording") {
                HStack {
                    Image(systemName: permissionManager.hasScreenRecordingPermission
                        ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(permissionManager.hasScreenRecordingPermission ? .green : .red)
                    Text(permissionManager.hasScreenRecordingPermission ? "Granted" : "Not Granted")
                    if !permissionManager.hasScreenRecordingPermission {
                        Button("Open Settings") {
                            permissionManager.openScreenRecordingSettings()
                        }
                    }
                }
            }

            LabeledContent("Accessibility") {
                HStack {
                    Image(systemName: permissionManager.hasAccessibilityPermission
                        ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(permissionManager.hasAccessibilityPermission ? .green : .red)
                    Text(permissionManager.hasAccessibilityPermission ? "Granted" : "Not Granted")
                    if !permissionManager.hasAccessibilityPermission {
                        Button("Request") {
                            permissionManager.requestAccessibilityPermission()
                        }
                    }
                }
            }

            Text("Clicher requires Screen Recording permission to capture your screen, and Accessibility permission for global hotkeys.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            await permissionManager.checkAllPermissions()
        }
    }
}
