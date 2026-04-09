import XCTest
@testable import VitaminDTrackerCore

/// One-off probe to answer "what UV does the app show in Cabo right now?".
/// Not a real assertion test — it just prints. Delete after reading.
final class UVProbeTests: XCTestCase {

    func testProbeCaboRightNow() {
        let cabo = HomeLocation(cityName: "Cabo San Lucas", country: "Mexico",
                                latitude: 22.8905, longitude: -109.9167)

        let now = Date()
        let nowUVI = BaselineEstimator.estimateUVIndex(location: cabo, date: now)

        let mst = TimeZone(identifier: "America/Mazatlan")!
        let fmt = DateFormatter()
        fmt.timeZone = mst
        fmt.dateFormat = "EEE MMM d, h:mm a zzz"

        print("\n═══════════════════════════════════════════════════")
        print("  \(fmt.string(from: now))")
        print("  Clear-sky model: UV \(String(format: "%.2f", nowUVI))")
        print("  isUVSufficientForSession: \(nowUVI >= 3.0)")
        print("═══════════════════════════════════════════════════")

        print("\nFull-day curve — clear-sky model, Cabo (today, MST):")
        print("─────────────────────────────────────────────────")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = mst
        let dayComps = cal.dateComponents([.year, .month, .day], from: now)

        for halfHour in 10...40 {  // 5:00 → 20:00
            let h = halfHour / 2
            let m = (halfHour % 2) * 30
            var c = dayComps
            c.hour = h; c.minute = m; c.timeZone = mst
            let d = cal.date(from: c)!
            let uv = BaselineEstimator.estimateUVIndex(location: cabo, date: d)
            let bar = String(repeating: "█", count: Int((uv * 4).rounded()))
            let mark = uv >= 3.0 ? " ←" : ""
            print(String(format: "  %02d:%02d  UV %5.2f  %@%@", h, m, uv, bar, mark))
        }
        print("─────────────────────────────────────────────────")
        print("← = UV ≥ 3 (vitamin D production threshold)\n")
    }
}
