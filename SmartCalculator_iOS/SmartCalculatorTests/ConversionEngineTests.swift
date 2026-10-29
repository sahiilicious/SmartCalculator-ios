import XCTest
@testable import SmartCalculator

final class ConversionEngineTests: XCTestCase {

    private func convert(_ value: Double, _ from: String, _ to: String,
                         _ category: ConversionCategory,
                         file: StaticString = #filePath, line: UInt = #line) throws -> Double {
        guard let fromUnit = category.unit(withID: from), let toUnit = category.unit(withID: to) else {
            XCTFail("Unknown unit \(from) or \(to)", file: file, line: line)
            return .nan
        }
        let input = Decimal(string: String(format: "%.15f", value), locale: Locale(identifier: "en_US_POSIX")) ?? 0
        return try ConversionEngine.convert(input, from: fromUnit, to: toUnit, category: category).doubleValue
    }

    private func check(_ value: Double, _ from: String, _ to: String, _ category: ConversionCategory,
                       equals expected: Double, accuracy: Double = 1e-9,
                       file: StaticString = #filePath, line: UInt = #line) {
        do {
            let result = try convert(value, from, to, category, file: file, line: line)
            XCTAssertEqual(result, expected, accuracy: accuracy, "\(value) \(from) -> \(to)", file: file, line: line)
        } catch {
            XCTFail("Unexpected error \(error)", file: file, line: line)
        }
    }

    // MARK: Length
    func testLength() {
        check(1, "km", "m", .length, equals: 1000)
        check(1, "in", "cm", .length, equals: 2.54)
        check(1, "mi", "km", .length, equals: 1.609344)
        check(1, "ft", "in", .length, equals: 12)
        check(1, "yd", "ft", .length, equals: 3)
        check(1, "nmi", "m", .length, equals: 1852)
        check(1, "um", "mm", .length, equals: 0.001)
        check(1, "nm", "m", .length, equals: 1e-9, accuracy: 1e-18)
        check(5280, "ft", "mi", .length, equals: 1)
    }

    // MARK: Weight
    func testWeight() {
        check(1, "kg", "g", .weight, equals: 1000)
        check(1, "lb", "g", .weight, equals: 453.59237)
        check(1, "lb", "oz", .weight, equals: 16)
        check(1, "st", "lb", .weight, equals: 14)
        check(1, "t", "kg", .weight, equals: 1000)
        check(1000, "mg", "g", .weight, equals: 1)
        check(1_000_000, "ug", "g", .weight, equals: 1)
    }

    // MARK: Volume
    func testVolume() {
        check(1, "l", "ml", .volume, equals: 1000)
        check(1, "m3", "l", .volume, equals: 1000)
        check(1, "cm3", "ml", .volume, equals: 1)
        check(1, "us_gal", "l", .volume, equals: 3.785411784)
        check(1, "imp_gal", "l", .volume, equals: 4.54609)
        check(1, "us_gal", "us_floz", .volume, equals: 128)
        check(1, "us_gal", "us_qt", .volume, equals: 4)
        check(1, "us_qt", "us_pt", .volume, equals: 2)
        check(1, "us_pt", "us_cup", .volume, equals: 2)
        check(1, "us_cup", "us_tbsp", .volume, equals: 16)
        check(1, "us_tbsp", "us_tsp", .volume, equals: 3)
    }

    func testUSAndImperialGallonsAreDifferent() {
        check(1, "imp_gal", "us_gal", .volume, equals: 1.200949925, accuracy: 1e-8)
    }

    // MARK: Temperature
    func testTemperatureKnownValues() {
        check(0, "c", "f", .temperature, equals: 32)
        check(100, "c", "f", .temperature, equals: 212)
        check(0, "c", "k", .temperature, equals: 273.15)
        check(32, "f", "c", .temperature, equals: 0)
        check(212, "f", "c", .temperature, equals: 100)
        check(273.15, "k", "c", .temperature, equals: 0)
        check(-40, "c", "f", .temperature, equals: -40)
        check(-40, "f", "c", .temperature, equals: -40)
        check(98.6, "f", "c", .temperature, equals: 37, accuracy: 1e-9)
        check(300, "k", "f", .temperature, equals: 80.33, accuracy: 1e-9)
        check(25, "c", "c", .temperature, equals: 25)
    }

    func testTemperatureBelowAbsoluteZeroThrows() {
        XCTAssertThrowsError(try convert(-300, "c", "f", .temperature)) {
            XCTAssertEqual($0 as? ConversionError, .belowAbsoluteZero)
        }
        XCTAssertThrowsError(try convert(-1, "k", "c", .temperature))
        XCTAssertThrowsError(try convert(-500, "f", "c", .temperature))
    }

    func testAbsoluteZeroItselfIsAllowed() {
        check(-273.15, "c", "k", .temperature, equals: 0)
        check(0, "k", "c", .temperature, equals: -273.15)
    }

    // MARK: Speed
    func testSpeed() {
        check(1, "ms", "kmh", .speed, equals: 3.6)
        check(3.6, "kmh", "ms", .speed, equals: 1)
        check(1, "mph", "kmh", .speed, equals: 1.609344)
        check(1, "kn", "kmh", .speed, equals: 1.852)
        check(1, "fps", "ms", .speed, equals: 0.3048)
        // 1 hour = 3600 seconds: 1 m/s covers 3600 m in an hour = 3.6 km/h
        check(3600, "ms", "kmh", .speed, equals: 12960)
    }

    // MARK: Angle
    func testAngle() {
        check(180, "deg", "rad", .angle, equals: Double.pi, accuracy: 1e-12)
        check(Double.pi, "rad", "deg", .angle, equals: 180, accuracy: 1e-9)
        check(90, "deg", "grad", .angle, equals: 100)
        check(1, "deg", "arcmin", .angle, equals: 60)
        check(1, "deg", "arcsec", .angle, equals: 3600)
        check(360, "deg", "rad", .angle, equals: 2 * Double.pi, accuracy: 1e-12)
        check(-90, "deg", "grad", .angle, equals: -100)
    }

    // MARK: Area
    func testArea() {
        check(1, "ha", "m2", .area, equals: 10_000)
        check(1, "km2", "ha", .area, equals: 100)
        check(1, "ac", "m2", .area, equals: 4046.8564224)
        check(1, "mi2", "ac", .area, equals: 640, accuracy: 1e-6)
        check(1, "ft2", "in2", .area, equals: 144)
        check(1, "yd2", "ft2", .area, equals: 9)
        check(1, "m2", "cm2", .area, equals: 10_000)
        check(1, "cm2", "mm2", .area, equals: 100)
    }

    // MARK: Validation and boundaries
    func testNegativeNotAllowedForLength() {
        XCTAssertThrowsError(try convert(-1, "m", "ft", .length)) {
            XCTAssertEqual($0 as? ConversionError, .negativeNotAllowed)
        }
    }

    func testNegativeAllowedForSpeedAndAngle() {
        check(-10, "ms", "kmh", .speed, equals: -36)
    }

    func testOutOfRange() {
        XCTAssertThrowsError(try convert(1e16, "m", "km", .length)) {
            XCTAssertEqual($0 as? ConversionError, .outOfRange)
        }
    }

    func testZeroConvertsToZero() {
        check(0, "km", "mi", .length, equals: 0)
    }

    func testLargestAllowedValue() {
        check(1e15, "m", "km", .length, equals: 1e12, accuracy: 1)
    }

    func testVerySmallValue() {
        check(1e-12, "m", "nm", .length, equals: 1e-3, accuracy: 1e-12)
    }

    // MARK: Catalog integrity
    func testEveryFactorIsPositive() {
        for category in ConversionCategory.allCases {
            XCTAssertFalse(category.units.isEmpty, "\(category)")
            for unit in category.units {
                XCTAssertGreaterThan(unit.factor, 0, "\(category).\(unit.id)")
            }
        }
    }

    func testUnitIDsAreUniqueInEachCategory() {
        for category in ConversionCategory.allCases {
            let ids = category.units.map { $0.id }
            XCTAssertEqual(Set(ids).count, ids.count, "\(category)")
        }
    }

    func testDefaultUnitsExist() {
        for category in ConversionCategory.allCases {
            XCTAssertNotNil(category.unit(withID: category.defaultUnitIDs.from), "\(category)")
            XCTAssertNotNil(category.unit(withID: category.defaultUnitIDs.to), "\(category)")
        }
    }

    func testRequiredUnitCounts() {
        XCTAssertEqual(ConversionCategory.length.units.count, 11)
        XCTAssertEqual(ConversionCategory.weight.units.count, 8)
        XCTAssertEqual(ConversionCategory.volume.units.count, 12)
        XCTAssertEqual(ConversionCategory.temperature.units.count, 3)
        XCTAssertEqual(ConversionCategory.speed.units.count, 5)
        XCTAssertEqual(ConversionCategory.angle.units.count, 5)
        XCTAssertEqual(ConversionCategory.area.units.count, 10)
    }

    func testRoundTripReturnsOriginalValue() throws {
        for category in ConversionCategory.allCases where category != .temperature {
            let units = category.units
            for from in units {
                for to in units {
                    let there = try ConversionEngine.convert(123.456, from: from, to: to, category: category)
                    let back = try ConversionEngine.convert(there, from: to, to: from, category: category)
                    XCTAssertEqual(back.doubleValue, 123.456, accuracy: 1e-6, "\(category) \(from.id)->\(to.id)")
                }
            }
        }
    }
}
