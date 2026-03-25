import SwiftUI

/// 権限設定ガイド画面
/// 初回起動時や権限が不足している場合に表示
struct PermissionGuideView: View {
    let permissionManager: PermissionManager
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // ヘッダー
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Clicher を使うには権限が必要です")
                .font(.title2)
                .fontWeight(.semibold)

            Text("スクリーンショットとグローバルホットキーを使用するために、以下の権限を許可してください。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 権限カード
            VStack(spacing: 16) {
                permissionCard(
                    title: "Screen Recording",
                    description: "画面の内容をキャプチャするために必要です",
                    systemImage: "rectangle.dashed.and.arrow.up",
                    isGranted: permissionManager.hasScreenRecordingPermission,
                    action: permissionManager.requestScreenRecording
                )

                permissionCard(
                    title: "Accessibility",
                    description: "グローバルホットキー (⌘⇧A) の動作に必要です",
                    systemImage: "keyboard",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    action: permissionManager.requestAccessibility
                )
            }

            Spacer()

            // 続行ボタン
            Button {
                permissionManager.checkAll()
                onDismiss()
            } label: {
                Text(allPermissionsGranted ? "始める" : "あとで設定する")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(allPermissionsGranted ? .accentColor : .secondary)
        }
        .padding(32)
        .frame(width: 420, height: 480)
        .onAppear {
            permissionManager.checkAll()
        }
    }

    private var allPermissionsGranted: Bool {
        permissionManager.hasScreenRecordingPermission
            && permissionManager.hasAccessibilityPermission
    }

    private func permissionCard(
        title: String,
        description: String,
        systemImage: String,
        isGranted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button("許可") {
                    action()
                }
                .controlSize(.small)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
