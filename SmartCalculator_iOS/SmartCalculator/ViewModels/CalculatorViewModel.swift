import Foundation
import SwiftUI

/// Connects the calculator screen to `CalculatorEngine` and keeps the history list.
@MainActor
final class CalculatorViewModel: ObservableObject {
    /// Maximum number of history items kept.
    static let maxHistoryCount = 100

    @Published private(set) var engine: CalculatorEngine
    @Published private(set) var history: [HistoryEntry]

    private let store: HistoryStoring

    init(engine: CalculatorEngine = CalculatorEngine(),
         store: HistoryStoring = UserDefaultsHistoryStore()) {
        self.engine = engine
        self.store = store
        self.history = store.load()
    }

    // MARK: - Display

    var displayText: String { engine.displayText }
    var expressionText: String { engine.expressionText }
    var pendingOperator: CalculatorOperator? { engine.pendingOperator }

    /// Accessibility text for the big display.
    var accessibilityValue: String {
        let expression = engine.expressionText
        return expression.isEmpty ? engine.displayText : "\(expression) \(engine.displayText)"
    }

    // MARK: - Actions

    func handle(_ key: CalcKey) {
        Haptics.tap()
        switch key {
        case .digit(let digit): engine.inputDigit(digit)
        case .decimal: engine.inputDecimalPoint()
        case .op(let op): engine.inputOperator(op)
        case .clear: engine.clearAll()
        case .backspace: engine.backspace()
        case .percent: engine.percent()
        case .sign: engine.toggleSign()
        case .equals:
            if let entry = engine.equals() {
                history.insert(entry, at: 0)
                if history.count > Self.maxHistoryCount {
                    history.removeLast(history.count - Self.maxHistoryCount)
                }
                store.save(history)
            }
        }
    }

    /// Loads a past result back into the calculator.
    func reuse(_ entry: HistoryEntry) {
        guard let value = Decimal(string: entry.rawValue, locale: Locale(identifier: "en_US_POSIX")) else { return }
        engine.load(value: value)
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        store.save(history)
    }

    func clearHistory() {
        history.removeAll()
        store.save(history)
    }
}
