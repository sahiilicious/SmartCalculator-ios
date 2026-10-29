import Foundation

/// One unit inside a converter category (for example "Kilometer").
struct ConversionUnit: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    /// How many *base units* one of this unit equals (base = meter, gram, litre, m/s, degree, m²).
    /// Not used for temperature, which needs formulas instead of a factor.
    let factor: Decimal
    /// Optional clarification, e.g. "US customary".
    let note: String?

    init(_ id: String, _ name: String, _ symbol: String, factor: Decimal = 1, note: String? = nil) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.factor = factor
        self.note = note
    }
}

/// The seven unit-conversion categories.
enum ConversionCategory: String, CaseIterable, Identifiable, Hashable {
    case length, weight, volume, temperature, speed, angle, area

    var id: String { rawValue }

    var title: String {
        switch self {
        case .length: return "Length"
        case .weight: return "Weight & Mass"
        case .volume: return "Volume"
        case .temperature: return "Temperature"
        case .speed: return "Speed"
        case .angle: return "Angle"
        case .area: return "Area"
        }
    }

    var subtitle: String {
        switch self {
        case .length: return "mm, m, km, in, ft, mi…"
        case .weight: return "g, kg, lb, oz, stone…"
        case .volume: return "mL, L, cups, gallons…"
        case .temperature: return "°C, °F and Kelvin"
        case .speed: return "m/s, km/h, mph, knots"
        case .angle: return "Degrees, radians, grads"
        case .area: return "m², hectare, acre…"
        }
    }

    /// Names of the base unit used inside the conversion engine (for documentation only).
    var baseUnitName: String {
        switch self {
        case .length: return "meter"
        case .weight: return "gram"
        case .volume: return "litre"
        case .temperature: return "degree Celsius"
        case .speed: return "meter per second"
        case .angle: return "degree"
        case .area: return "square meter"
        }
    }

    /// Temperature, speed and angle can legitimately be negative; the others cannot.
    var allowsNegativeValues: Bool {
        switch self {
        case .temperature, .speed, .angle: return true
        default: return false
        }
    }

    var units: [ConversionUnit] {
        switch self {
        case .length: return UnitCatalog.length
        case .weight: return UnitCatalog.weight
        case .volume: return UnitCatalog.volume
        case .temperature: return UnitCatalog.temperature
        case .speed: return UnitCatalog.speed
        case .angle: return UnitCatalog.angle
        case .area: return UnitCatalog.area
        }
    }

    /// Unit ids selected the first time the screen opens.
    var defaultUnitIDs: (from: String, to: String) {
        switch self {
        case .length: return ("km", "mi")
        case .weight: return ("kg", "lb")
        case .volume: return ("l", "us_gal")
        case .temperature: return ("c", "f")
        case .speed: return ("kmh", "mph")
        case .angle: return ("deg", "rad")
        case .area: return ("m2", "ft2")
        }
    }

    func unit(withID id: String?) -> ConversionUnit? {
        guard let id = id else { return nil }
        return units.first { $0.id == id }
    }
}

/// All conversion factors in one place. Factors are written as exact decimal strings so no
/// binary floating-point noise is introduced. Sources: SI definitions and the international
/// yard-and-pound agreement (1 in = 25.4 mm, 1 lb = 0.45359237 kg), US gallon = 231 in³.
enum UnitCatalog {
    private static func d(_ text: String) -> Decimal { Decimal.exact(text) }

    /// π with 36 significant digits (Decimal holds up to 38).
    static let pi = d("3.14159265358979323846264338327950288")

    // Base unit: meter
    static let length: [ConversionUnit] = [
        ConversionUnit("mm", "Millimeter", "mm", factor: d("0.001")),
        ConversionUnit("cm", "Centimeter", "cm", factor: d("0.01")),
        ConversionUnit("m", "Meter", "m", factor: d("1")),
        ConversionUnit("km", "Kilometer", "km", factor: d("1000")),
        ConversionUnit("in", "Inch", "in", factor: d("0.0254")),
        ConversionUnit("ft", "Foot", "ft", factor: d("0.3048")),
        ConversionUnit("yd", "Yard", "yd", factor: d("0.9144")),
        ConversionUnit("mi", "Mile", "mi", factor: d("1609.344")),
        ConversionUnit("um", "Micrometer", "µm", factor: d("0.000001")),
        ConversionUnit("nm", "Nanometer", "nm", factor: d("0.000000001")),
        ConversionUnit("nmi", "Nautical Mile", "nmi", factor: d("1852"))
    ]

    // Base unit: gram
    static let weight: [ConversionUnit] = [
        ConversionUnit("ug", "Microgram", "µg", factor: d("0.000001")),
        ConversionUnit("mg", "Milligram", "mg", factor: d("0.001")),
        ConversionUnit("g", "Gram", "g", factor: d("1")),
        ConversionUnit("kg", "Kilogram", "kg", factor: d("1000")),
        ConversionUnit("t", "Metric Tonne", "t", factor: d("1000000")),
        ConversionUnit("oz", "Ounce", "oz", factor: d("28.349523125")),
        ConversionUnit("lb", "Pound", "lb", factor: d("453.59237")),
        ConversionUnit("st", "Stone", "st", factor: d("6350.29318"))
    ]

    // Base unit: litre
    static let volume: [ConversionUnit] = [
        ConversionUnit("ml", "Milliliter", "mL", factor: d("0.001")),
        ConversionUnit("l", "Liter", "L", factor: d("1")),
        ConversionUnit("cm3", "Cubic Centimeter", "cm³", factor: d("0.001")),
        ConversionUnit("m3", "Cubic Meter", "m³", factor: d("1000")),
        ConversionUnit("us_tsp", "US Teaspoon", "tsp", factor: d("0.00492892159375"), note: "US customary"),
        ConversionUnit("us_tbsp", "US Tablespoon", "tbsp", factor: d("0.01478676478125"), note: "US customary"),
        ConversionUnit("us_floz", "US Fluid Ounce", "fl oz", factor: d("0.0295735295625"), note: "US customary"),
        ConversionUnit("us_cup", "US Cup", "cup", factor: d("0.2365882365"), note: "US customary"),
        ConversionUnit("us_pt", "US Pint", "pt", factor: d("0.473176473"), note: "US customary"),
        ConversionUnit("us_qt", "US Quart", "qt", factor: d("0.946352946"), note: "US customary"),
        ConversionUnit("us_gal", "US Gallon", "gal (US)", factor: d("3.785411784"), note: "US customary"),
        ConversionUnit("imp_gal", "Imperial Gallon", "gal (UK)", factor: d("4.54609"), note: "British imperial")
    ]

    // Temperature uses formulas; `factor` is unused. Ids are matched in ConversionEngine.
    static let temperature: [ConversionUnit] = [
        ConversionUnit("c", "Celsius", "°C"),
        ConversionUnit("f", "Fahrenheit", "°F"),
        ConversionUnit("k", "Kelvin", "K")
    ]

    // Base unit: meter per second
    static let speed: [ConversionUnit] = [
        ConversionUnit("ms", "Meters per Second", "m/s", factor: d("1")),
        ConversionUnit("kmh", "Kilometers per Hour", "km/h", factor: d("1") / d("3.6")),
        ConversionUnit("mph", "Miles per Hour", "mph", factor: d("0.44704")),
        ConversionUnit("fps", "Feet per Second", "ft/s", factor: d("0.3048")),
        ConversionUnit("kn", "Knots", "kn", factor: d("1852") / d("3600"))
    ]

    // Base unit: degree
    static let angle: [ConversionUnit] = [
        ConversionUnit("deg", "Degrees", "°", factor: d("1")),
        ConversionUnit("rad", "Radians", "rad", factor: d("180") / pi),
        ConversionUnit("grad", "Gradians", "grad", factor: d("0.9")),
        ConversionUnit("arcmin", "Arcminutes", "′", factor: d("1") / d("60")),
        ConversionUnit("arcsec", "Arcseconds", "″", factor: d("1") / d("3600"))
    ]

    // Base unit: square meter
    static let area: [ConversionUnit] = [
        ConversionUnit("mm2", "Square Millimeter", "mm²", factor: d("0.000001")),
        ConversionUnit("cm2", "Square Centimeter", "cm²", factor: d("0.0001")),
        ConversionUnit("m2", "Square Meter", "m²", factor: d("1")),
        ConversionUnit("km2", "Square Kilometer", "km²", factor: d("1000000")),
        ConversionUnit("ha", "Hectare", "ha", factor: d("10000")),
        ConversionUnit("ac", "Acre", "ac", factor: d("4046.8564224")),
        ConversionUnit("in2", "Square Inch", "in²", factor: d("0.00064516")),
        ConversionUnit("ft2", "Square Foot", "ft²", factor: d("0.09290304")),
        ConversionUnit("yd2", "Square Yard", "yd²", factor: d("0.83612736")),
        ConversionUnit("mi2", "Square Mile", "mi²", factor: d("2589988.110336"))
    ]
}
