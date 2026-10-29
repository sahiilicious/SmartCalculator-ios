import XCTest
@testable import SmartCalculator

@MainActor
final class CalculatorViewModelTests: XCTestCase {
    private func makeViewModel(store: MemoryHistoryStore = MemoryHistoryStore()) -> CalculatorViewModel {
        CalculatorViewModel(engine: CalculatorEngine(locale: Locale(identifier: "en_US")), store: store)
    }

    private func press(_ vm: CalculatorViewModel, _ keys: [CalcKey]) {
        keys.forEach { vm.handle($0) }
    }

    func testCalculationAddsHistory() {
        let store = MemoryHistoryStore()
        let vm = makeViewModel(store: store)
        press(vm, [.digit("2"), .op(.add), .digit("3"), .equals])
        XCTAssertEqual(vm.displayText, "5")
        XCTAssertEqual(vm.history.count, 1)
        XCTAssertEqual(vm.history.first?.expression, "2 + 3")
        XCTAssertEqual(store.stored.count, 1)
    }

    func testHistoryNewestFirstAndClear() {
        let vm = makeViewModel()
        press(vm, [.digit("1"), .op(.add), .digit("1"), .equals, .clear])
        press(vm, [.digit("2"), .op(.multiply), .digit("2"), .equals])
        XCTAssertEqual(vm.history.first?.result, "4")
        vm.clearHistory()
        XCTAssertTrue(vm.history.isEmpty)
    }

    func testReuseHistoryEntry() {
        let vm = makeViewModel()
        press(vm, [.digit("7"), .op(.multiply), .digit("6"), .equals, .clear])
        guard let entry = vm.history.first else { return XCTFail("No history") }
        vm.reuse(entry)
        XCTAssertEqual(vm.displayText, "42")
    }

    func testDeleteHistoryRow() {
        let vm = makeViewModel()
        press(vm, [.digit("1"), .op(.add), .digit("1"), .equals])
        vm.deleteHistory(at: IndexSet(integer: 0))
        XCTAssertTrue(vm.history.isEmpty)
    }

    func testDivisionByZeroDoesNotAddHistory() {
        let vm = makeViewModel()
        press(vm, [.digit("1"), .op(.divide), .digit("0"), .equals])
        XCTAssertTrue(vm.history.isEmpty)
        XCTAssertEqual(vm.displayText, "Cannot divide by zero")
    }

    func testHistoryIsCapped() {
        let vm = makeViewModel()
        for _ in 0..<(CalculatorViewModel.maxHistoryCount + 5) {
            press(vm, [.clear, .digit("1"), .op(.add), .digit("1"), .equals])
        }
        XCTAssertEqual(vm.history.count, CalculatorViewModel.maxHistoryCount)
    }

    func testKeypadLayoutHasTwentyKeys() {
        XCTAssertEqual(CalcKey.layout.count, 5)
        XCTAssertTrue(CalcKey.layout.allSatisfy { $0.count == 4 })
    }
}

@MainActor
final class UnitConverterViewModelTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    private func make(_ category: ConversionCategory, defaults: UserDefaults? = nil) -> UnitConverterViewModel {
        UnitConverterViewModel(category: category, defaults: defaults ?? makeDefaults(), locale: us)
    }

    func testEmptyInput() {
        let vm = make(.length)
        XCTAssertEqual(vm.outcome, .empty)
        XCTAssertEqual(vm.resultText, "—")
        XCTAssertNil(vm.errorMessage)
    }

    func testImmediateRecalculationWhenInputChanges() {
        let vm = make(.length)           // default km -> mi
        vm.inputText = "1"
        XCTAssertEqual(vm.resultText, "0.621371192237")
        vm.inputText = "10"
        XCTAssertEqual(vm.resultText, "6.21371192237")
    }

    func testRecalculationWhenUnitChanges() {
        let vm = make(.length)
        vm.inputText = "1"
        if let metre = ConversionCategory.length.unit(withID: "m") { vm.toUnit = metre }
        XCTAssertEqual(vm.resultText, "1,000")
    }

    func testSwapUnits() {
        let vm = make(.length)
        let from = vm.fromUnit, to = vm.toUnit
        vm.swapUnits()
        XCTAssertEqual(vm.fromUnit, to)
        XCTAssertEqual(vm.toUnit, from)
    }

    func testTemperatureDefaults() {
        let vm = make(.temperature)
        vm.inputText = "0"
        XCTAssertEqual(vm.resultText, "32")
        vm.inputText = "-40"
        XCTAssertEqual(vm.resultText, "-40")
    }

    func testInvalidInputShowsError() {
        let vm = make(.weight)
        vm.inputText = "12abc"
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.hasResult)
    }

    func testNegativeLengthShowsError() {
        let vm = make(.length)
        vm.inputText = "-5"
        XCTAssertEqual(vm.errorMessage, ConversionError.negativeNotAllowed.errorDescription)
    }

    func testBelowAbsoluteZeroShowsError() {
        let vm = make(.temperature)
        vm.inputText = "-500"
        XCTAssertEqual(vm.errorMessage, ConversionError.belowAbsoluteZero.errorDescription)
    }

    func testOutOfRangeShowsError() {
        let vm = make(.area)
        vm.inputText = "99999999999999999999"
        XCTAssertEqual(vm.errorMessage, ConversionError.outOfRange.errorDescription)
    }

    func testResetClearsInput() {
        let vm = make(.speed)
        vm.inputText = "5"
        vm.reset()
        XCTAssertEqual(vm.inputText, "")
    }

    func testRelationText() {
        let vm = make(.length)
        XCTAssertEqual(vm.relationText, "1 km = 0.621371192237 mi")
    }

    func testSelectedUnitsArePersisted() {
        let defaults = makeDefaults()
        let first = make(.volume, defaults: defaults)
        if let cup = ConversionCategory.volume.unit(withID: "us_cup") { first.fromUnit = cup }
        let second = make(.volume, defaults: defaults)
        XCTAssertEqual(second.fromUnit.id, "us_cup")
    }
}
