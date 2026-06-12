import Foundation

// MARK: - Daily AI-scan quota (free tier)
//
// Device-local: resets at local midnight, persisted in UserDefaults.
// Premium users never consult this. Interface-level bookkeeping only —
// Mochi never sees scan counts.

enum ScanQuota {
    static let freeDailyLimit = 3

    private static let dayKey  = "scanQuotaDay"
    private static let usedKey = "scanQuotaUsed"

    static func used(now: Date = .now) -> Int {
        guard UserDefaults.standard.string(forKey: dayKey) == dayString(now) else { return 0 }
        return UserDefaults.standard.integer(forKey: usedKey)
    }

    static func remaining(now: Date = .now) -> Int {
        max(freeDailyLimit - used(now: now), 0)
    }

    static func recordScan(now: Date = .now) {
        let count = used(now: now)
        UserDefaults.standard.set(dayString(now), forKey: dayKey)
        UserDefaults.standard.set(count + 1, forKey: usedKey)
    }

    private static func dayString(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}
