import Foundation
import HealthKit
import Combine

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    @Published var isAuthorized     = false
    @Published var activeCalories   = 0      // burned from HealthKit today
    @Published var restingCalories  = 0      // BMR from HealthKit today

    // Types we read
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .basalEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!
    ]

    // Types we write
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            isAuthorized = true
            await fetchTodayCalories()
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    // MARK: - Fetch today's burned calories

    func fetchTodayCalories() async {
        async let active  = fetchSum(identifier: .activeEnergyBurned)
        async let resting = fetchSum(identifier: .basalEnergyBurned)
        let (a, r) = await (active, resting)
        activeCalories  = Int(a)
        restingCalories = Int(r)
    }

    private func fetchSum(identifier: HKQuantityTypeIdentifier) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let predicate  = HKQuery.predicateForSamples(withStart: startOfDay, end: .now)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType:   type,
                quantitySamplePredicate: predicate,
                options:        .cumulativeSum
            ) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: val)
            }
            store.execute(query)
        }
    }

    // MARK: - Write active calories burned (manual log)

    func logBurnedCalories(_ kcal: Double) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        let sample   = HKQuantitySample(
            type:       type,
            quantity:   quantity,
            start:      .now,
            end:        .now
        )
        try await store.save(sample)
        await fetchTodayCalories()     // refresh
    }

    // MARK: - Write body weight

    func logBodyWeight(_ kg: Double) async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample   = HKQuantitySample(type: type, quantity: quantity, start: .now, end: .now)
        try await store.save(sample)
    }

    // MARK: - Fetch latest body weight from Health

    func fetchLatestWeight() async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let sort  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    var totalBurnedToday: Int { activeCalories + restingCalories }
}
