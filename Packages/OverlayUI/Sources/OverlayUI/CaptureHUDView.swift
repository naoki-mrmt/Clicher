import SwiftUI
import SharedModels

/// キャプチャHUDのSwiftUIビュー
/// モード選択グリッドとオプションバーを表示
public struct CaptureHUDView: View {
    public let appState: AppState
    public let onModeSelected: (CaptureMode) -> Void
    public let onDismiss: () -> Void

    public init(
        appState: AppState,
        onModeSelected: @escaping (CaptureMode) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.appState = appState
        self.onModeSelected = onModeSelected
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            header

            Divider()
                .padding(.horizontal, 16)

            // モード選択グリッド
            modeGrid
                .padding(.vertical, 12)

            Divider()
                .padding(.horizontal, 16)

            // オプションバー
            optionBar
                .padding(.vertical, 10)
        }
        .frame(width: 400)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "camera.viewfinder")
                .font(.title3)
            Text("Clicher")
                .font(.headline)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Mode Grid

    private var modeGrid: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ]

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(CaptureMode.allCases) { mode in
                modeButton(mode)
            }
        }
        .padding(.horizontal, 16)
    }

    private func modeButton(_ mode: CaptureMode) -> some View {
        Button {
            onModeSelected(mode)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topLeading) {
                    Image(systemName: mode.systemImage)
                        .font(.title2)
                        .frame(height: 28)

                    Text(mode.shortcutKey)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .offset(x: -8, y: -4)
                }

                Text(mode.label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                mode == appState.selectedCaptureMode
                    ? AnyShapeStyle(.tint.opacity(0.15))
                    : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        mode == appState.selectedCaptureMode ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!mode.isAvailable)
        .opacity(mode.isAvailable ? 1 : 0.4)
    }

    // MARK: - Option Bar

    private var optionBar: some View {
        HStack(spacing: 16) {
            // タイマー
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: Bindable(appState).timerDelay) {
                    ForEach(TimerDelay.allCases) { delay in
                        Text(delay.label).tag(delay)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }

            Divider()
                .frame(height: 16)

            // クロスヘア
            Toggle(isOn: Bindable(appState).showCrosshair) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.viewfinder")
                        .font(.caption)
                    Text("クロスヘア")
                        .font(.caption)
                }
            }
            .toggleStyle(.checkbox)

            // ルーペ
            Toggle(isOn: Bindable(appState).showMagnifier) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                    Text("ルーペ")
                        .font(.caption)
                }
            }
            .toggleStyle(.checkbox)

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}
