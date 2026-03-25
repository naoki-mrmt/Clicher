import Testing
@testable import SharedModels

@Suite("FileNamePattern Tests")
struct FileNamePatternTests {
    @Test("all cases have non-empty labels")
    func labelsExist() {
        for pattern in FileNamePattern.allCases {
            #expect(!pattern.label.isEmpty)
        }
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for pattern in FileNamePattern.allCases {
            #expect(pattern.id == pattern.rawValue)
        }
    }
}

@Suite("OverlayPosition Tests")
struct OverlayPositionTests {
    @Test("all cases have non-empty labels")
    func labelsExist() {
        for position in OverlayPosition.allCases {
            #expect(!position.label.isEmpty)
        }
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for position in OverlayPosition.allCases {
            #expect(position.id == position.rawValue)
        }
    }
}

@Suite("AnnotationToolType Tests")
struct AnnotationToolTypeTests {
    @Test("all cases have non-empty labels")
    func labelsExist() {
        for tool in AnnotationToolType.allCases {
            #expect(!tool.label.isEmpty)
        }
    }

    @Test("all cases have non-empty systemImage")
    func systemImagesExist() {
        for tool in AnnotationToolType.allCases {
            #expect(!tool.systemImage.isEmpty)
        }
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for tool in AnnotationToolType.allCases {
            #expect(tool.id == tool.rawValue)
        }
    }
}
