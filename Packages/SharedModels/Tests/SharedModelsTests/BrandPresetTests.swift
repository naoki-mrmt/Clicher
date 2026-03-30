import Testing
import Foundation
@testable import SharedModels

@Suite("BrandPreset Tests")
struct BrandPresetTests {
    @Test("default preset has correct initial values")
    func defaultValues() {
        let preset = BrandPreset()
        #expect(preset.name == "新規プリセット")
        #expect(preset.logoPosition == .bottomRight)
        #expect(preset.logoOpacity == 0.8)
        #expect(preset.fontSize == 24)
        #expect(preset.isDefault == false)
        #expect(preset.logoImageData == nil)
    }

    @Test("preset is Codable (encode/decode roundtrip)")
    func codableRoundtrip() throws {
        let preset = BrandPreset(
            name: "Test Brand",
            primaryColor: .red,
            secondaryColor: .blue,
            accentColor: .white,
            logoPosition: .topLeft,
            isDefault: true
        )

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(BrandPreset.self, from: data)

        #expect(decoded.name == "Test Brand")
        #expect(decoded.primaryColor == .red)
        #expect(decoded.logoPosition == .topLeft)
        #expect(decoded.isDefault == true)
        #expect(decoded.id == preset.id)
    }

    @Test("CodableColor creates correct CGColor")
    func codableColorToCGColor() {
        let color = CodableColor(red: 0.5, green: 0.3, blue: 0.8, alpha: 0.9)
        let cg = color.cgColor
        #expect(cg.numberOfComponents == 4)
    }

    @Test("LogoPosition has labels for all cases")
    func logoPositionLabels() {
        for position in LogoPosition.allCases {
            #expect(!position.label.isEmpty)
        }
    }

    @Test("GradientConfig has correct defaults")
    func gradientDefaults() {
        let config = GradientConfig()
        #expect(config.angle == 135)
    }

    @Test("ExportConfig has correct defaults")
    func exportDefaults() {
        let config = ExportConfig()
        #expect(config.format == "png")
        #expect(config.quality == 0.9)
        #expect(config.scale == 2.0)
    }
}
