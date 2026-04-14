import CoreGraphics
import AppKit
import OSLog

/// 複数フレームを縦方向にスティッチするユーティリティ
/// 重複領域をピクセルマッチングで検出し、自然に結合する
public enum ImageStitcher {
    /// フレームを縦方向にスティッチ
    /// - Parameters:
    ///   - images: スティッチする画像配列（上から下の順）
    ///   - searchRange: 重複検索範囲（ピクセル）、画像の高さの割合で制限
    /// - Returns: スティッチされた画像、または失敗時に nil
    public static func stitchVertically(images: [CGImage], searchRange: Int = 0) -> CGImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }

        // 各ペアの重複量を計算
        var overlaps: [Int] = []
        for i in 0..<(images.count - 1) {
            let overlap = findOverlap(top: images[i], bottom: images[i + 1], searchRange: searchRange)
            overlaps.append(overlap)
        }

        // 最終画像の高さを計算
        let width = images[0].width
        var totalHeight = images[0].height
        for i in 1..<images.count {
            totalHeight += images[i].height - overlaps[i - 1]
        }

        // 結合画像を描画
        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            Logger.capture.error("ImageStitcher: CGContext 作成失敗")
            return nil
        }

        // CGContext は左下原点なので、上から描く場合は y を計算
        var currentY = totalHeight - images[0].height
        context.draw(images[0], in: CGRect(x: 0, y: currentY, width: width, height: images[0].height))

        for i in 1..<images.count {
            currentY -= (images[i].height - overlaps[i - 1])
            context.draw(images[i], in: CGRect(x: 0, y: currentY, width: width, height: images[i].height))
        }

        let result = context.makeImage()
        Logger.capture.info("ImageStitcher: \(images.count) フレーム → \(width)x\(totalHeight)")
        return result
    }

    /// 2つの画像の重複領域をピクセル比較で検出
    /// top の下端と bottom の上端の一致する行数を返す
    private static func findOverlap(top: CGImage, bottom: CGImage, searchRange: Int) -> Int {
        let width = min(top.width, bottom.width)
        let maxSearch = searchRange > 0 ? searchRange : min(top.height, bottom.height) * 3 / 4

        guard let topData = top.dataProvider?.data as Data?,
              let bottomData = bottom.dataProvider?.data as Data? else {
            return 0
        }

        let topBytesPerRow = top.bytesPerRow
        let bottomBytesPerRow = bottom.bytesPerRow
        let bytesPerPixel = top.bitsPerPixel / 8

        // 比較対象のピクセル数を制限（高速化のためサンプリング）
        let sampleStep = max(1, width / 100)
        let sampleCount = width / sampleStep

        var bestOverlap = 0
        var bestScore: Double = 0

        // 重複量を大→小で探索（大きい重複ほど優先）
        for overlap in stride(from: min(maxSearch, bottom.height - 1), through: 10, by: -1) {
            var matchPixels = 0
            let compareRows = min(overlap, 5) // 先頭5行で高速チェック

            for row in 0..<compareRows {
                let topRow = top.height - overlap + row
                let bottomRow = row

                guard topRow >= 0, topRow < top.height, bottomRow < bottom.height else { continue }

                let topOffset = topRow * topBytesPerRow
                let bottomOffset = bottomRow * bottomBytesPerRow

                for sx in stride(from: 0, to: width, by: sampleStep) {
                    let topIdx = topOffset + sx * bytesPerPixel
                    let bottomIdx = bottomOffset + sx * bytesPerPixel

                    guard topIdx + 2 < topData.count, bottomIdx + 2 < bottomData.count else { continue }

                    let dr = abs(Int(topData[topIdx]) - Int(bottomData[bottomIdx]))
                    let dg = abs(Int(topData[topIdx + 1]) - Int(bottomData[bottomIdx + 1]))
                    let db = abs(Int(topData[topIdx + 2]) - Int(bottomData[bottomIdx + 2]))

                    if dr < 12 && dg < 12 && db < 12 {
                        matchPixels += 1
                    }
                }
            }

            let totalSamples = compareRows * sampleCount
            guard totalSamples > 0 else { continue }
            let score = Double(matchPixels) / Double(totalSamples)

            if score > 0.85 && score > bestScore {
                bestScore = score
                bestOverlap = overlap
            }
        }

        Logger.capture.debug("ImageStitcher overlap: \(bestOverlap)px (score: \(String(format: "%.2f", bestScore)))")
        return bestOverlap
    }
}
