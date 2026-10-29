import Foundation

/// The four arithmetic operators supported by the calculator.
enum CalculatorOperator: String, CaseIterable, Codable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"

    /// Higher number = evaluated first (so × and ÷ run before + and −).
    var precedence: Int {
        switch self {
        case .add, .subtract: return 1
        case .multiply, .divide: return 2
        }
    }

    /// Applies the operator to two numbers.
    /// - Throws: `CalculatorError.divisionByZero` or `.overflow`.
    func apply(_ lhs: Decimal, _ rhs: Decimal) throws -> Decimal {
        let raw: Decimal
        switch self {
        case .add: raw = lhs + rhs
        case .subtract: raw = lhs - rhs
        case .multiply: raw = lhs * rhs
        case .divide:
            guard rhs != 0 else { throw CalculatorError.divisionByZero }
            raw = lhs / rhs
        }
        guard !raw.isNaN else { throw CalculatorError.overflow }
        // Round away binary/decimal noise such as 0.1 + 0.2 = 0.30000000000000004 (Decimal avoids
        // that already; this also trims endless results like 1 / 3).
        let rounded = raw.rounded(toPlaces: 12)
        guard !rounded.isNaN else { throw CalculatorError.overflow }
        return rounded
    }
}

/// One element of the expression being built: a number or an operator.
enum ExpressionToken: Equatable {
    case number(Decimal)
    case op(CalculatorOperator)
}

/// Errors the calculator can show on its display (it never crashes on bad input).
enum CalculatorError: Error, Equatable {
    case divisionByZero
    case invalidExpression
    case overflow

    var message: String {
        switch self {
        case .divisionByZero: return "Cannot divide by zero"
        case .invalidExpression: return "Invalid expression"
        case .overflow: return "Number too large"
        }
    }
}

/// A finished calculation stored in the history list.
struct HistoryEntry: Codable, Identifiable, Equatable {
    var id: UUID
    let expression: String
    /// Formatted for display, e.g. "1,234.5".
    let result: String
    /// Plain "1234.5" text used to re-load the value into the calculator.
    let rawValue: String
    let date: Date

    init(id: UUID = UUID(), expression: String, result: String, rawValue: String, date: Date = Date()) {
        self.id = id
        self.expression = expression
        self.result = result
        self.rawValue = rawValue
        self.date = date
    }
}

/// Every key on the calculator keypad.
enum CalcKey: Hashable {
    case digit(String)
    case decimal
    case op(CalculatorOperator)
    case equals
    case clear
    case backspace
    case percent
    case sign

    var id: String {
        switch self {
        case .digit(let d): return "digit-\(d)"
        case .decimal: return "decimal"
        case .op(let o): return "op-\(o.rawValue)"
        case .equals: return "equals"
        case .clear: return "clear"
        case .backspace: return "backspace"
        case .percent: return "percent"
        case .sign: return "sign"
        }
    }

    /// Text used by VoiceOver.
    var accessibilityLabel: String {
        switch self {
        case .digit(let d): return d
        case .decimal: return "Decimal point"
        case .op(let o):
            switch o {
            case .add: return "Plus"
            case .subtract: return "Minus"
            case .multiply: return "Times"
            case .divide: return "Divided by"
            }
        case .equals: return "Equals"
        case .clear: return "All clear"
        case .backspace: return "Delete"
        case .percent: return "Percent"
        case .sign: return "Plus or minus"
        }
    }

    /// The 5 x 4 keypad layout, top row first.
    static let layout: [[CalcKey]] = [
        [.clear, .backspace, .percent, .op(.divide)],
        [.digit("7"), .digit("8"), .digit("9"), .op(.multiply)],
        [.digit("4"), .digit("5"), .digit("6"), .op(.subtract)],
        [.digit("1"), .digit("2"), .digit("3"), .op(.add)],
        [.sign, .digit("0"), .decimal, .equals]
    ]
}
