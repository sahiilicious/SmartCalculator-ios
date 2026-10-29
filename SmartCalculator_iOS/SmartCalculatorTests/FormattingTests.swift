import XCTest
@testable import SmartCalculator

final class FormattingTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    func testCalculatorStringBasics() {
        XCTAssertEqual(NumberFormatting.calculatorString(0, locale: us), "0")
        XCTAssertEqual(NumberFormatting.calculatorString(1234.5, locale: us), "1,234.5")
        XCTAssertEqual(NumberFormatting.calculatorString(-42, locale: us), "-42")
        XCTAssertEqual(NumberFormatting.calculatorString(Decimal(string: "0.3") ?? 0, locale: us), "0.3")
    }

    func testTinyNegativeDoesNotShowNegativeZero() {
        let tiny = Decimal(string: "-0.00000000001") ?? 0
        XCTAssertEqual(NumberFormatting.calculatorString(tiny, locale: us), "0")
    }

    func testScientificNotationForHugeAndTiny() {
        XCTAssertTrue(NumberFormatting.calculatorString(Decimal(sign: .plus, exponent: 20, significand: 1), locale: us).contains("E"))
        XCTAssertTrue(NumberFormatting.converterString(Decimal(string: "0.0000001") ?? 0, locale: us).contains("E"))
    }

    func testConverterStringHidesNoise() {
        let noisy = Decimal(string: "0.6213711922373340") ?? 0
        XCTAssertEqual(NumberFormatting.converterString(noisy, locale: us), "0.621371192237")
        XCTAssertEqual(NumberFormatting.converterString(1000, locale: us), "1,000")
    }

    func testEntryStringKeepsTrailingPointAndZeros() {
        XCTAssertEqual(NumberFormatting.entryString("1234.", locale: us), "1,234.")
        XCTAssertEqual(NumberFormatting.entryString("0.50", locale: us), "0.50")
        XCTAssertEqual(NumberFormatting.entryString("-1234567", locale: us), "-1,234,567")
        XCTAssertEqual(NumberFormatting.entryString("", locale: us), "0")
    }

    func testCurrencyAmount() {
        XCTAssertEqual(NumberFormatting.currencyAmount(1234.5, locale: us), "1,234.50")
        XCTAssertEqual(NumberFormatting.currencyAmount(0.012345, locale: us), "0.012345")
        XCTAssertEqual(NumberFormatting.currencyAmount(.nan, locale: us), "—")
    }

    func testInputParser() {
        XCTAssertEqual(InputParser.parse("12.5", locale: us), .valid(Decimal(string: "12.5") ?? 0))
        XCTAssertEqual(InputParser.parse("", locale: us), .empty)
        XCTAssertEqual(InputParser.parse("   ", locale: us), .empty)
        XCTAssertEqual(InputParser.parse("abc", locale: us), .invalid)
        XCTAssertEqual(InputParser.parse("12abc", locale: us), .invalid)
    }

    func testInputParserUsesLocaleDecimalSeparator() {
        let german = Locale(identifier: "de_DE")
        XCTAssertEqual(InputParser.parse("12,5", locale: german), .valid(Decimal(string: "12.5") ?? 0))
    }

    func testDecimalExactHelper() {
        XCTAssertEqual(Decimal.exact("0.3048").doubleValue, 0.3048, accuracy: 1e-15)
        XCTAssertEqual(Decimal.exact("not a number"), 0)
    }
}
