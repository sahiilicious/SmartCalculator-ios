import Foundation

/// The calculator "brain". It has no UI code, so it can be unit-tested easily.
///
/// How it works:
/// * The number being typed is kept as text in `entry` (so "0.50" keeps its trailing zero).
/// * When an operator is pressed, the number and operator are pushed onto `tokens`.
/// * Pressing "=" evaluates `tokens` with the usual precedence (× and ÷ before + and −).
/// * All arithmetic uses `Decimal`, so 0.1 + 0.2 is exactly 0.3.
struct CalculatorEngine {
    /// Maximum number of digits that can be typed for one number.
    static let maxDigits = 15

    private(set) var tokens: [ExpressionToken] = []
    private(set) var entry: String = ""
    private(set) var lastResult: Decimal?
    private(set) var justEvaluated = false
    private(set) var completedExpression = ""
    private(set) var error: CalculatorError?
    private var repeatOperation: (op: CalculatorOperator, operand: Decimal)?

    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    // MARK: - What the screen shows

    /// Big number line.
    var displayText: String {
        if let error = error { return error.message }
        if !entry.isEmpty { return NumberFormatting.entryString(entry, locale: locale) }
        if justEvaluated, let result = lastResult {
            return NumberFormatting.calculatorString(result, locale: locale)
        }
        if tokens.count >= 2, case .number(let previous) = tokens[tokens.count - 2] {
            return NumberFormatting.calculatorString(previous, locale: locale)
        }
        return "0"
    }

    /// Small line above the number, e.g. "12 + 3 ×".
    var expressionText: String {
        if error != nil { return "" }
        if justEvaluated {
            return completedExpression.isEmpty ? "" : completedExpression + " ="
        }
        var text = describe(tokens)
        if !entry.isEmpty {
            text += (text.isEmpty ? "" : " ") + NumberFormatting.entryString(entry, locale: locale)
        }
        return text
    }

    /// Operator that was just pressed and is waiting for the next number (used to highlight a key).
    var pendingOperator: CalculatorOperator? {
        guard error == nil, entry.isEmpty, !justEvaluated, let last = tokens.last else { return nil }
        if case .op(let op) = last { return op }
        return nil
    }

    var hasError: Bool { error != nil }

    // MARK: - Key handling

    mutating func inputDigit(_ digit: String) {
        guard digit.count == 1, digit.first?.isNumber == true else { return }
        prepareForNewEntry()
        if entry == "0" {
            entry = digit
        } else if entry == "-0" {
            entry = "-" + digit
        } else {
            guard digitCount(entry) < Self.maxDigits else { return }
            entry += digit
        }
    }

    mutating func inputDecimalPoint() {
        prepareForNewEntry()
        if entry.isEmpty {
            entry = "0."
        } else if !entry.contains(".") {
            guard digitCount(entry) < Self.maxDigits else { return }
            entry += "."
        }
    }

    mutating func inputOperator(_ op: CalculatorOperator) {
        if error != nil { return }

        if justEvaluated, let result = lastResult {
            // Continue calculating with the previous result: "5 + 3 =" then "× 2".
            tokens = [.number(result), .op(op)]
            entry = ""
            justEvaluated = false
            completedExpression = ""
            repeatOperation = nil
            return
        }

        if !entry.isEmpty {
            guard let number = parse(entry) else { return }
            tokens.append(.number(number))
            tokens.append(.op(op))
            entry = ""
            return
        }

        if let last = tokens.last {
            // Pressing a second operator replaces the first one.
            if case .op = last {
                tokens.removeLast()
                tokens.append(.op(op))
            }
            return
        }

        // Nothing typed yet: treat as "0 op".
        tokens = [.number(0), .op(op)]
    }

    mutating func toggleSign() {
        if error != nil { return }
        if !entry.isEmpty {
            if entry == "0" { return }
            if entry.hasPrefix("-") {
                entry.removeFirst()
            } else {
                entry = "-" + entry
            }
            return
        }
        if justEvaluated, let result = lastResult {
            lastResult = -result
            return
        }
        entry = "-0"
    }

    /// Percent: "50 %" -> 0.5, and "200 + 10 %" -> 20 (10 % of 200).
    mutating func percent() {
        if error != nil { return }
        if !entry.isEmpty, let value = parse(entry) {
            var newValue = value / 100
            if let last = tokens.last,
               case .op(let op) = last,
               op == .add || op == .subtract,
               let base = try? Self.evaluate(Array(tokens.dropLast())) {
                newValue = base * value / 100
            }
            entry = newValue.rounded(toPlaces: 12).plainString
        } else if justEvaluated, let result = lastResult {
            lastResult = (result / 100).rounded(toPlaces: 12)
        }
    }

    mutating func backspace() {
        if error != nil {
            resetAll()
            return
        }
        if justEvaluated { return }
        if !entry.isEmpty {
            entry.removeLast()
            if entry == "-" { entry = "" }
            return
        }
        // Remove a trailing operator and bring the previous number back for editing.
        if let last = tokens.last, case .op = last {
            tokens.removeLast()
            if case .number(let number)? = tokens.last {
                tokens.removeLast()
                entry = number.plainString
            }
        }
    }

    mutating func clearAll() {
        resetAll()
    }

    /// Replaces everything with a single value (used when re-opening a history item).
    mutating func load(value: Decimal) {
        resetAll()
        entry = value.plainString
    }

    /// Evaluates the expression. Returns a history item when a calculation was performed.
    @discardableResult
    mutating func equals() -> HistoryEntry? {
        if error != nil { return nil }

        var working = tokens

        if justEvaluated {
            // Repeat the last operation: "2 + 3 =" gives 5, pressing "=" again gives 8.
            guard let result = lastResult, let repeatOp = repeatOperation else { return nil }
            working = [.number(result), .op(repeatOp.op), .number(repeatOp.operand)]
        } else {
            if !entry.isEmpty {
                guard let number = parse(entry) else { return nil }
                working.append(.number(number))
            } else if let last = working.last, case .op = last {
                // "5 +" then "=": use the previous number as the second operand (5 + 5).
                if working.count >= 2, case .number(let previous) = working[working.count - 2] {
                    working.append(.number(previous))
                } else {
                    working.removeLast()
                }
            }
            if working.isEmpty { return nil }

            if working.count == 1, case .number(let only) = working[0] {
                // Just a number and "=": show it as the result, no history entry.
                lastResult = only
                tokens = []
                entry = ""
                justEvaluated = true
                repeatOperation = nil
                completedExpression = ""
                return nil
            }
        }

        do {
            let value = try Self.evaluate(working)
            let expressionString = describe(working)

            if working.count >= 3,
               case .op(let op) = working[working.count - 2],
               case .number(let operand) = working[working.count - 1] {
                repeatOperation = (op, operand)
            }

            lastResult = value
            tokens = []
            entry = ""
            justEvaluated = true
            completedExpression = expressionString

            return HistoryEntry(expression: expressionString,
                                result: NumberFormatting.calculatorString(value, locale: locale),
                                rawValue: value.plainString)
        } catch let calculatorError as CalculatorError {
            setError(calculatorError)
            return nil
        } catch {
            setError(.invalidExpression)
            return nil
        }
    }

    // MARK: - Expression evaluation (static so tests can call it directly)

    /// Evaluates a list like [2, +, 3, ×, 4] with operator precedence (result 14).
    /// Uses two stacks: one for numbers, one for operators (the "shunting-yard" idea).
    static func evaluate(_ tokens: [ExpressionToken]) throws -> Decimal {
        guard !tokens.isEmpty else { throw CalculatorError.invalidExpression }

        var values: [Decimal] = []
        var operators: [CalculatorOperator] = []
        var expectingNumber = true

        func applyTopOperator() throws {
            guard let op = operators.popLast(),
                  let right = values.popLast(),
                  let left = values.popLast() else {
                throw CalculatorError.invalidExpression
            }
            values.append(try op.apply(left, right))
        }

        for token in tokens {
            switch token {
            case .number(let number):
                guard expectingNumber else { throw CalculatorError.invalidExpression }
                values.append(number)
                expectingNumber = false
            case .op(let op):
                guard !expectingNumber else { throw CalculatorError.invalidExpression }
                while let top = operators.last, top.precedence >= op.precedence {
                    try applyTopOperator()
                }
                operators.append(op)
                expectingNumber = true
            }
        }

        guard !expectingNumber else { throw CalculatorError.invalidExpression }
        while !operators.isEmpty {
            try applyTopOperator()
        }
        guard values.count == 1, let result = values.first else { throw CalculatorError.invalidExpression }
        return result
    }

    // MARK: - Private helpers

    private mutating func prepareForNewEntry() {
        if error != nil { resetAll() }
        if justEvaluated {
            tokens = []
            entry = ""
            lastResult = nil
            justEvaluated = false
            completedExpression = ""
            repeatOperation = nil
        }
    }

    private mutating func resetAll() {
        tokens = []
        entry = ""
        lastResult = nil
        justEvaluated = false
        completedExpression = ""
        error = nil
        repeatOperation = nil
    }

    private mutating func setError(_ newError: CalculatorError) {
        error = newError
        tokens = []
        entry = ""
        lastResult = nil
        justEvaluated = false
        completedExpression = ""
        repeatOperation = nil
    }

    private func digitCount(_ text: String) -> Int {
        text.filter { $0.isNumber }.count
    }

    private func parse(_ text: String) -> Decimal? {
        var cleaned = text
        if cleaned.hasSuffix(".") { cleaned.removeLast() }
        if cleaned.isEmpty || cleaned == "-" { return 0 }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func describe(_ tokens: [ExpressionToken]) -> String {
        tokens.map { token -> String in
            switch token {
            case .number(let number): return NumberFormatting.calculatorString(number, locale: locale)
            case .op(let op): return op.rawValue
            }
        }.joined(separator: " ")
    }
}
