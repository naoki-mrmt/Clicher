import Foundation
import OSLog
import SharedModels

/// ブランドプリセットの永続化ストレージ
/// ~/Library/Application Support/Clicher/presets/ に JSON 保存
@MainActor
public final class BrandPresetStore {
    private let presetsDirectory: URL

    public init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        self.presetsDirectory = appSupport
            .appendingPathComponent("Clicher")
            .appendingPathComponent("presets")

        // ディレクトリがなければ作成
        do {
            try FileManager.default.createDirectory(
                at: presetsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            Logger.app.error("プリセットディレクトリ作成失敗: \(error)")
        }
    }

    /// テスト用: カスタムディレクトリを指定
    public init(directory: URL) {
        self.presetsDirectory = directory
        do {
            try FileManager.default.createDirectory(
                at: presetsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            Logger.app.error("プリセットディレクトリ作成失敗: \(error)")
        }
    }

    // MARK: - CRUD

    /// 全プリセットを読み込み
    public func loadAll() -> [BrandPreset] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: presetsDirectory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }

            return files.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(BrandPreset.self, from: data)
            }
        } catch {
            Logger.app.error("プリセット読み込み失敗: \(error)")
            return []
        }
    }

    /// プリセットを保存
    public func save(_ preset: BrandPreset) throws {
        let url = presetsDirectory.appendingPathComponent("\(preset.id.uuidString).json")
        let data = try JSONEncoder().encode(preset)
        try data.write(to: url)
        Logger.app.info("プリセット保存: \(preset.name)")
    }

    /// プリセットを削除
    public func delete(_ preset: BrandPreset) throws {
        let url = presetsDirectory.appendingPathComponent("\(preset.id.uuidString).json")
        try FileManager.default.removeItem(at: url)
        Logger.app.info("プリセット削除: \(preset.name)")
    }

    /// デフォルトプリセットを取得
    public func defaultPreset() -> BrandPreset? {
        loadAll().first { $0.isDefault }
    }

    // MARK: - Import / Export (.clipreset)

    /// .clipreset ファイルにエクスポート（JSON + ロゴをzip化）
    public func exportToClipreset(_ preset: BrandPreset, to url: URL) throws {
        let data = try JSONEncoder().encode(preset)
        try data.write(to: url)
        Logger.app.info("プリセットエクスポート: \(preset.name) → \(url.lastPathComponent)")
    }

    /// .clipreset ファイルからインポート
    public func importFromClipreset(at url: URL) throws -> BrandPreset {
        let data = try Data(contentsOf: url)
        let preset = try JSONDecoder().decode(BrandPreset.self, from: data)
        try save(preset)
        Logger.app.info("プリセットインポート: \(preset.name)")
        return preset
    }
}
