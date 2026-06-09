import Testing
import Foundation
@testable import EasyFit

struct MochiStateEngineTests {
    let cal = Calendar.current
    let config = MochiConfig.default

    private func date(daysAgo: Int, hour: Int = 12) -> Date {
        let day = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    // MARK: - computeState

    @Test func newUserIsContent() {
        let state = MochiStateEngine.computeState(lastLog: nil, loggedToday: false, streak: 0)
        #expect(state == .content)
    }

    @Test func loggedTodayIsAtLeastHappy() {
        let now = date(daysAgo: 0, hour: 14)
        let state = MochiStateEngine.computeState(
            lastLog: now, loggedToday: true, streak: 1, now: now)
        #expect(state == .happy)
    }

    @Test func loggedTodayInEveningStaysHappyNotSleepy() {
        let now = date(daysAgo: 0, hour: 22)
        let state = MochiStateEngine.computeState(
            lastLog: now, loggedToday: true, streak: 1, now: now)
        #expect(state == .happy)
    }

    @Test func threeDayStreakIsEcstatic() {
        let now = date(daysAgo: 0, hour: 14)
        let state = MochiStateEngine.computeState(
            lastLog: now, loggedToday: true, streak: 3, now: now)
        #expect(state == .ecstatic)
    }

    @Test func eveningWithoutLogIsSleepy() {
        let now = date(daysAgo: 0, hour: 20)
        let lastLog = date(daysAgo: 0, hour: 8).addingTimeInterval(-3600 * 18) // ~yesterday
        let state = MochiStateEngine.computeState(
            lastLog: lastLog, loggedToday: false, streak: 2, now: now)
        #expect(state == .sleepy)
    }

    @Test func over24HoursWithoutLogIsMissingYou() {
        let now = date(daysAgo: 0, hour: 14)
        let state = MochiStateEngine.computeState(
            lastLog: now.addingTimeInterval(-3600 * 25), loggedToday: false, streak: 0, now: now)
        #expect(state == .missingYou)
    }

    @Test func morningWithoutLogYetIsContent() {
        let now = date(daysAgo: 0, hour: 9)
        let state = MochiStateEngine.computeState(
            lastLog: now.addingTimeInterval(-3600 * 15), loggedToday: false, streak: 4, now: now)
        #expect(state == .content)
    }

    // MARK: - mealStreak (grace rule)

    @Test func emptyTodayDoesNotBreakStreak() {
        let dates = [date(daysAgo: 1), date(daysAgo: 2), date(daysAgo: 3)]
        #expect(MochiStateEngine.mealStreak(entryDates: dates) == 3)
    }

    @Test func todayCountsWhenLogged() {
        let dates = [date(daysAgo: 0), date(daysAgo: 1)]
        #expect(MochiStateEngine.mealStreak(entryDates: dates) == 2)
    }

    @Test func gapBreaksStreak() {
        let dates = [date(daysAgo: 0), date(daysAgo: 2), date(daysAgo: 3)]
        #expect(MochiStateEngine.mealStreak(entryDates: dates) == 1)
    }

    @Test func multipleLogsSameDayCountOnce() {
        let dates = [date(daysAgo: 0, hour: 8), date(daysAgo: 0, hour: 19), date(daysAgo: 1)]
        #expect(MochiStateEngine.mealStreak(entryDates: dates) == 2)
    }

    @Test func noEntriesIsZero() {
        #expect(MochiStateEngine.mealStreak(entryDates: []) == 0)
    }
}
