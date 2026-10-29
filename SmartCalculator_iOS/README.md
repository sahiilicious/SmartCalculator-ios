# Smart Calculator (iOS)

A SwiftUI app with a standard calculator (with history), a real-time currency converter and seven
unit converters (length, weight & mass, volume, temperature, speed, angle, area).
Built for a B.Tech CSE college project. Swift 5, SwiftUI, MVVM, **no third-party dependencies**.

> **Honest status:** this project was written and checked without access to a Mac, so it has
> **not been compiled or run in Xcode yet** (details in [Limitations](#limitations-and-what-was-not-tested)).
> Its Swift syntax was parsed, its Xcode project file was validated structurally and every
> conversion constant was cross-checked with exact arithmetic, but the first build on your Mac is the
> real test. If Xcode shows a compile error, see [Troubleshooting](#troubleshooting).

---

## 1. Open and run it (5 minutes)

**Requirements:** a Mac with **Xcode 15 or newer** (Xcode 14.1+ should also work), iOS 16+ simulator.

1. Unzip `SmartCalculator_iOS.zip`.
2. Double-click **`SmartCalculator.xcodeproj`**.
3. In the top bar choose the scheme **SmartCalculator** and an iPhone simulator (e.g. *iPhone 15*).
4. Press **⌘R** to run.
5. Press **⌘U** to run the unit tests.

**Running on a real iPhone (optional):** select the *SmartCalculator* target → *Signing & Capabilities* →
tick *Automatically manage signing* and choose your Apple ID team. Change the bundle identifier
`com.example.SmartCalculator` to something unique (e.g. `com.yourname.SmartCalculator`).
Running on the simulator needs no signing.

The currency converter needs internet on the first run (simulators use your Mac's connection).
Everything else works offline.

---

## 2. Features

| Screen | What it does |
|---|---|
| **Calculator** | + − × ÷, decimals, %, ± toggle, AC, backspace (⌫), operator precedence (2+3×4 = 14), repeated `=`, thousands separators, division-by-zero message, up to 15 digits, scientific notation for huge/tiny results, **history** (tap to reuse, swipe to delete, clear all) saved between launches |
| **Currency** | 160+ currencies, amount field, from/to pickers with search, swap, auto-calculation, rate + "last updated" time, loading spinner, error banners, **offline cache with a clear "saved rates, not live" notice** |
| **Length, Mass, Volume, Temperature, Speed, Angle, Area** | Amount field, from/to menus, swap, live result, unit symbols + full names, clear button, validation (empty / invalid / negative / too large / below absolute zero), last-used units remembered |
| **Settings** | Light / Dark / System theme, haptics on/off, attribution |

Units supported are exactly the ones in the assignment (11 length, 8 mass, 12 volume, 3 temperature,
5 speed, 5 angle, 10 area). US customary and imperial volumes are labelled separately
(*US Gallon* vs *Imperial Gallon*).

---

## 3. Project structure (MVVM)

```
SmartCalculator_iOS/
├── SmartCalculator.xcodeproj/        Xcode project (+ shared scheme)
├── SmartCalculator/
│   ├── SmartCalculatorApp.swift      App entry point
│   ├── Models/                       Plain data types
│   │   ├── CalculatorModels.swift      operators, tokens, errors, keypad keys, history entry
│   │   ├── ConversionModels.swift      ConversionCategory, ConversionUnit, UnitCatalog (all factors)
│   │   └── CurrencyModels.swift        ExchangeRates, error types, popular currencies
│   ├── Services/                     Logic with no UI
│   │   ├── CalculatorEngine.swift      expression building + evaluation (Decimal arithmetic)
│   │   ├── ConversionEngine.swift      ONE engine for every unit category (+ temperature formulas)
│   │   ├── CurrencyService.swift       API configuration, async/await download, JSON parsing
│   │   ├── RateCache.swift             saves last good rates (UserDefaults)
│   │   ├── HistoryStore.swift          saves calculator history (UserDefaults)
│   │   └── AppConfiguration.swift      which API, refresh intervals
│   ├── ViewModels/                   State for each screen (ObservableObject)
│   ├── Views/                        SwiftUI screens and reusable components (Theme.swift)
│   ├── Utilities/                    Number formatting/parsing, Decimal helpers, settings keys
│   ├── Assets.xcassets/              App icon, accent color, launch background color
│   └── Info.plist                    Launch screen, portrait orientation
├── SmartCalculatorTests/             XCTest unit tests (~140 assertions)
├── tools/generate_xcodeproj.py       Optional: rebuilds the .xcodeproj from the files on disk
├── project.yml                       Optional: XcodeGen spec (fallback)
└── README.md
```

**How the pieces talk:** `View` → shows state from a `ViewModel` → which calls a `Service/Engine`.
Views never contain conversion formulas, so the maths is written once and tested once.

### Design decisions you can explain in your viva

* **`Decimal`, not `Double`, for calculator and unit maths.** `0.1 + 0.2` is exactly `0.3` with
  `Decimal`; with `Double` it is `0.30000000000000004`. Conversion factors are written as exact
  decimal strings (`"0.3048"`), and results are rounded to 12 significant digits for display.
* **Base-unit conversion.** Every linear category stores "how many base units is 1 of this unit".
  `result = value × fromFactor ÷ toFactor`. Adding a new unit is a single line in `UnitCatalog`.
* **Temperature uses formulas** (`°F = °C × 9/5 + 32`, `K = °C + 273.15`) with Celsius as the middle step,
  and rejects values below absolute zero.
* **Operator precedence** is handled by a two-stack ("shunting-yard" style) evaluator in
  `CalculatorEngine.evaluate`.
* **Currency:** one request fetches all rates relative to USD; any pair is `rate(to) ÷ rate(from)`.
* **Testability:** the engines, the currency parser and the view models take their dependencies
  (service, cache, defaults, clock) as parameters, so tests use fakes instead of the network.

---

## 4. Currency API setup

| | |
|---|---|
| **Provider** | [ExchangeRate-API](https://www.exchangerate-api.com) – *Open Access* endpoint |
| **Endpoint** | `GET https://open.er-api.com/v6/latest/USD` |
| **API key** | **None needed** for the default setup |
| **Currencies** | ~160 (includes INR, USD, EUR, GBP, JPY, CAD, AUD, CNY, AED, SGD) |
| **Update frequency** | The provider publishes new rates **once per day** |
| **Rate limit** | Throttled for abuse. If you ask too often you get HTTP 429 and must wait about 20 minutes. Requesting once a day never hits this. |
| **Terms** | Attribution is required ("Rates By Exchange Rate API" link – already shown in the Currency and Settings screens). You may cache the data. |

The app protects the limit itself: rates downloaded less than 1 hour ago are not downloaded again
when you open the screen, and the refresh button ignores taps within 5 minutes of a download
(see `AppConfiguration.swift`).

**How "live / cached" is decided (nothing stale is shown as live):**
* A successful download → rates are shown normally with the provider's "last updated" time.
* Download fails but an earlier download exists → an orange banner says
  *"Showing saved rates from <date>. They are not live."* and shows the error.
* No download has ever succeeded (first launch offline) → an error banner with **Try again**; no
  numbers are invented. There is **no hard-coded rate anywhere in the app.**

**Using a different provider or your own key:** open `Services/AppConfiguration.swift`:

```swift
// default
static let currencyAPI: CurrencyAPIConfiguration = .openAccess
// with a free key from exchangerate-api.com (https://v6.exchangerate-api.com/v6/KEY/latest/USD)
static let currencyAPI: CurrencyAPIConfiguration = .keyed("YOUR_API_KEY")
```

Any provider whose JSON looks like `{"result":"success","rates":{"USD":1,"INR":83.2,…}}` (or with
`conversion_rates`) works by setting `urlTemplate` with `{base}` / `{key}` placeholders. For other
JSON shapes, edit `CurrencyService.parse` only. Do not commit real API keys to a public repository.

---

## 5. Tests

Run with **⌘U** in Xcode (or `xcodebuild test -scheme SmartCalculator -destination 'platform=iOS Simulator,name=iPhone 15'`).

| File | Covers |
|---|---|
| `CalculatorEngineTests` | arithmetic, decimals, negatives, precedence, division by zero, repeat `=`, percent, backspace, digit limit, formatting, overflow |
| `ConversionEngineTests` | all 7 categories with known values (1 km = 1000 m, 1 kg = 1000 g, 0 °C = 32 °F, 0 °C = 273.15 K, 180° = π rad, 1 ha = 10 000 m², 1 US gal = 128 fl oz, …), invalid/boundary input, round-trip test for every unit pair, catalog integrity |
| `FormattingTests` | number formatting, scientific notation, input parsing (incl. a German locale) |
| `CurrencyTests` | JSON parsing (open + keyed), error responses, bad data, URL building, cross-rate maths, cache, view-model behaviour with a fake service (live, cached, offline, throttling) |
| `ViewModelTests` | calculator history, unit-converter live recalculation, validation messages, saved unit choices |

Note on "1 hour = 3600 seconds": the app has no time converter (it was not in the brief), so the
speed tests express the same fact (`1 m/s = 3.6 km/h`, i.e. 3600 m per hour).

Floating-point comparisons use `accuracy:` tolerances (`1e-9` unless stated).

---

## 6. Limitations and what was not tested

* **Not built or run on a Mac.** The author's environment had no Xcode/Swift compiler. What *was* verified:
  Swift syntax of all 29 files (parsed with the tree-sitter Swift grammar – 0 errors), the `.xcodeproj`
  structure (parsed and every object reference resolves), and all unit-conversion constants
  (re-computed with exact decimal arithmetic). What was **not** verified: type-checking, linking,
  UI appearance on a device, and the XCTest results. Expect to possibly fix a small compile error or
  a test expectation on first build.
* The currency screen needs internet at least once; rates are daily, not tick-by-tick, so they
  differ slightly from bank/card rates.
* Portrait iPhone only (iPad layout is not configured).
* The calculator has basic arithmetic only (no scientific functions or parentheses).
* App icon is a simple generated design – replace `Assets.xcassets/AppIcon.appiconset/AppIcon.png`
  (1024×1024, no transparency) with your own if you like.
* Bundle identifier is the placeholder `com.example.SmartCalculator`.
* VoiceOver labels are provided for keys, display and controls, but no formal accessibility audit was done.

---

## 7. Troubleshooting

* **"Signing for SmartCalculator requires a development team"** – only for real devices; choose the
  *iPhone simulator* or select your team under Signing & Capabilities.
* **A Swift compile error appears** – read the red message; most fixes are one line. Tell your
  instructor/AI assistant the exact message and file/line.
* **Test fails on number text (e.g. `1,000` vs `1.000`)** – tests pin the locale to `en_US`; if one still
  fails, check *Settings → Language & Region* of the simulator and send the failure message.
* **Project won't open / looks corrupt** – run `python3 tools/generate_xcodeproj.py` in the project
  folder, or install XcodeGen (`brew install xcodegen`) and run `xcodegen generate` (uses `project.yml`).
* **Currency says rate-limited (429)** – wait ~20 minutes; the provider throttles frequent requests.
* **Added a new Swift file outside Xcode** – re-run `tools/generate_xcodeproj.py`
  (files added through Xcode are registered automatically).

---

## 8. Credits

Exchange rates: [Rates By Exchange Rate API](https://www.exchangerate-api.com).
Unit definitions: SI units and the international yard & pound agreement (1 in = 25.4 mm, 1 lb = 0.45359237 kg);
US gallon = 231 in³; imperial gallon = 4.54609 L; international acre = 4046.8564224 m².
