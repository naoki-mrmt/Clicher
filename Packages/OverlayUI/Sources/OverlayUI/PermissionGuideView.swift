import SwiftUI
import SharedModels
import Utilities

/// 権限設定ガイド画面
/// 初回起動時や権限が不足している場合に表示
public struct PermissionGuideView: View {
    public let permissionManager: PermissionManager
    public var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var refreshTimer: Timer?

    public init(
        permissionManager: PermissionManager,
        onDismiss: @escaping () -> Void
    ) {
        self.permissionManager = permissionManager
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 24) {
            // ヘッダー
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text(L10n.permissionsRequired)
                .font(.title2)
                .fontWeight(.semibold)

            Text(L10n.permissionsDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // 権限カード
            VStack(spacing: 16) {
                permissionCard(
                    title: "Screen Recording",
                    description: L10n.screenRecordingDesc,
                    systemImage: "rectangle.dashed.and.arrow.up",
                    isGranted: permissionManager.hasScreenRecordingPermission,
                    action: permissionManager.requestScreenRecording
                )

                permissionCard(
                    title: "Accessibility",
                    description: L10n.accessibilityDesc,
                    systemImage: "keyboard",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    action: permissionManager.requestAccessibility
                )
            }

            Spacer()

            // 続行ボタン
            Button {
                onDismiss()
                dismiss()
            } label: {
                Text(allPermissionsGranted ? L10n.letsBegin : L10n.setUpLater)
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
            // 定期的に権限状態を再チェック（Grant後にシステム設定から戻った時用）
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    permissionManager.checkAll()
                }
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
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
                Button(L10n.grant) {
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
