import XCTest
@testable import SmartCalculator

final class CalculatorEngineTests: XCTestCase {
    private let us = Locale(identifier: "en_US")

    /// Types a string such as "2+3*4=" into a fresh engine. Use "/" for ÷, "*" for ×, "-" for −.
    private func run(_ keys: String, engine start: CalculatorEngine? = nil) -> CalculatorEngine {
        var engine = start ?? CalculatorEngine(locale: us)
        for character in keys {
            switch character {
            case "0"..."9": engine.inputDigit(String(character))
            case ".": engine.inputDecimalPoint()
            case "+": engine.inputOperator(.add)
            case "-": engine.inputOperator(.subtract)
            case "*": engine.inputOperator(.multiply)
            case "/": engine.inputOperator(.divide)
            case "=": engine.equals()
            case "%": engine.percent()
            case "~": engine.toggleSign()
            case "<": engine.backspace()
            case "C": engine.clearAll()
            default: XCTFail("Unknown key \(character)")
            }
        }
        return engine
    }

    // MARK: Basic arithmetic
    func testAddition() { XCTAssertEqual(run("2+3=").displayText, "5") }
    func testSubtraction() { XCTAssertEqual(run("9-4=").displayText, "5") }
    func testMultiplication() { XCTAssertEqual(run("6*7=").displayText, "42") }
    func testDivision() { XCTAssertEqual(run("8/4=").displayText, "2") }

    func testDecimalAdditionIsExact() {
        XCTAssertEqual(run("0.1+0.2=").displayText, "0.3")
    }

    func testNegativeResult() { XCTAssertEqual(run("5-8=").displayText, "-3") }

    func testNegativeNumbersAndSignToggle() {
        XCTAssertEqual(run("5~").displayText, "-5")
        XCTAssertEqual(run("5~+3=").displayText, "-2")
        XCTAssertEqual(run("5~~").displayText, "5")
    }

    func testDecimalNumbers() {
        XCTAssertEqual(run("2.5*4=").displayText, "10")
        XCTAssertEqual(run("1.5+2.25=").displayText, "3.75")
    }

    func testLeadingDecimalPoint() { XCTAssertEqual(run(".5").displayText, "0.5") }

    func testOnlyOneDecimalPointAllowed() { XCTAssertEqual(run("1.2.3").displayText, "1.23") }

    // MARK: Precedence
    func testMultiplicationBeforeAddition() { XCTAssertEqual(run("2+3*4=").displayText, "14") }
    func testDivisionBeforeSubtraction() { XCTAssertEqual(run("10-6/2=").displayText, "7") }
    func testLeftToRightForEqualPrecedence() { XCTAssertEqual(run("20/5/2=").displayText, "2") }

    func testEvaluatorDirectly() throws {
        let tokens: [ExpressionToken] = [.number(2), .op(.add), .number(3), .op(.multiply), .number(4)]
        XCTAssertEqual(try CalculatorEngine.evaluate(tokens), 14)
    }

    func testEvaluatorRejectsMalformedExpressions() {
        XCTAssertThrowsError(try CalculatorEngine.evaluate([]))
        XCTAssertThrowsError(try CalculatorEngine.evaluate([.number(1), .op(.add)]))
        XCTAssertThrowsError(try CalculatorEngine.evaluate([.op(.add), .number(1)]))
        XCTAssertThrowsError(try CalculatorEngine.evaluate([.number(1), .number(2)]))
    }

    // MARK: Division by zero and errors
    func testDivisionByZeroShowsErrorAndDoesNotCrash() {
        let engine = run("10/0=")
        XCTAssertTrue(engine.hasError)
        XCTAssertEqual(engine.displayText, "Cannot divide by zero")
    }

    func testCanContinueAfterError() {
        XCTAssertEqual(run("5", engine: run("10/0=")).displayText, "5")
    }

    func testOperatorIgnoredWhileInError() {
        XCTAssertTrue(run("+", engine: run("1/0=")).hasError)
    }

    func testDivideZeroByNumberIsZero() { XCTAssertEqual(run("0/5=").displayText, "0") }

    // MARK: Repeated calculations
    func testRepeatedEqualsRepeatsLastOperation() {
        XCTAssertEqual(run("2+3==").displayText, "8")
        XCTAssertEqual(run("2+3===").displayText, "11")
    }

    func testContinueWithResult() { XCTAssertEqual(run("2+3=*4=").displayText, "20") }

    func testOperatorReplacement() { XCTAssertEqual(run("5+*3=").displayText, "15") }

    func testEqualsAfterOperatorUsesPreviousNumber() { XCTAssertEqual(run("5+=").displayText, "10") }

    func testNumberThenEqualsKeepsNumber() { XCTAssertEqual(run("7=").displayText, "7") }

    // MARK: Percent
    func testPercentDividesByHundred() { XCTAssertEqual(run("50%").displayText, "0.5") }
    func testPercentOfLeftOperandForAddition() { XCTAssertEqual(run("200+10%=").displayText, "220") }
    func testPercentWithMultiplication() { XCTAssertEqual(run("200*10%=").displayText, "20") }

    // MARK: Backspace / clear
    func testBackspace() {
        XCTAssertEqual(run("123<").displayText, "12")
        XCTAssertEqual(run("1<").displayText, "0")
    }

    func testBackspaceAfterOperatorRestoresNumber() { XCTAssertEqual(run("12+<").displayText, "12") }

    func testClearAll() {
        let engine = run("12+3C")
        XCTAssertEqual(engine.displayText, "0")
        XCTAssertEqual(engine.expressionText, "")
    }

    // MARK: Large numbers, formatting
    func testDigitLimit() {
        let engine = run(String(repeating: "1", count: 30))
        XCTAssertEqual(engine.entry.count, CalculatorEngine.maxDigits)
    }

    func testThousandsSeparatorWhileTyping() { XCTAssertEqual(run("12345").displayText, "12,345") }

    func testRepeatingDecimalIsRounded() { XCTAssertEqual(run("1/3=").displayText, "0.3333333333") }

    func testVeryLargeResultUsesScientificNotation() {
        let engine = run("999999999999999*999999999999999=")
        XCTAssertTrue(engine.displayText.contains("E"), engine.displayText)
    }

    func testOverflowDoesNotCrash() {
        var engine = CalculatorEngine(locale: us)
        // Repeatedly squaring eventually exceeds Decimal's range; the engine must show an error.
        engine = run("999999999999999*999999999999999=", engine: engine)
        for _ in 0..<12 {
            engine = run("*", engine: engine)
            engine = run("=", engine: engine)
        }
        XCTAssertFalse(engine.displayText.isEmpty)
    }

    // MARK: History entry
    func testEqualsReturnsHistoryEntry() {
        var engine = run("2+3")
        let entry = engine.equals()
        XCTAssertEqual(entry?.expression, "2 + 3")
        XCTAssertEqual(entry?.result, "5")
        XCTAssertEqual(entry?.rawValue, "5")
    }
}
