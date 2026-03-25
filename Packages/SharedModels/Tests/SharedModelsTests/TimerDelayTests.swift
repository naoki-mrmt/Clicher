import Testing
@testable import SharedModels

@Suite("TimerDelay Tests")
struct TimerDelayTests {
    @Test("all cases have non-empty labels")
    func labelsExist() {
        for delay in TimerDelay.allCases {
            #expect(!delay.label.isEmpty)
        }
    }

    @Test("none has rawValue 0")
    func noneRawValue() {
        #expect(TimerDelay.none.rawValue == 0)
    }

    @Test("id matches rawValue")
    func idMatchesRawValue() {
        for delay in TimerDelay.allCases {
            #expect(delay.id == delay.rawValue)
        }
    }
}
