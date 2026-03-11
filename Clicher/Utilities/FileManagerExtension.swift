import Foundation

extension URL {
    /// Clicher のアプリサポートディレクトリ
    static var clicherApplicationSupport: URL {
        let base = URL.applicationSupportDirectory
        return base.appending(path: "Clicher")
    }

    /// キャプチャ保存用ディレクトリ
    static var clicherCaptures: URL {
        clicherApplicationSupport.appending(path: "Captures")
    }

    /// プリセット保存用ディレクトリ
    static var clicherPresets: URL {
        clicherApplicationSupport.appending(path: "Presets")
    }
}

/// ディレクトリの作成を保証するヘルパー
enum ClicherFileManager {
    /// 必要なアプリディレクトリを作成
    static func ensureDirectoriesExist() throws {
        let fm = FileManager.default
        let dirs = [URL.clicherApplicationSupport, URL.clicherCaptures, URL.clicherPresets]
        for dir in dirs {
            if !fm.fileExists(atPath: dir.path()) {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}
