import Foundation

// MARK: - All MochiView animation timing/feel constants
//
// Tune the character's feel from this one file. Durations in seconds,
// scales as multipliers, angles in degrees.

struct MochiMotion {
    // Breathing (bottom-anchored squash & stretch)
    var breathPeriod: Double        = 3.2
    var breathPeriodSleepy: Double  = 4.5
    var breathScaleY: Double        = 0.025   // 1.0 → 1.025
    var breathScaleYSleepy: Double  = 0.035   // slightly deeper
    var breathScaleX: Double        = 0.015   // inverse: 1.0 → 0.985

    // Idle sway
    var swayAmplitude: Double       = 1.2     // degrees
    var swayPeriod: Double          = 5.5
    var swayPhaseOffset: Double     = .pi / 3 // out of phase with breathing

    // Blinking
    var blinkInterval: ClosedRange<Double> = 3.0...7.0
    var blinkDuration: Double       = 0.13
    var doubleBlinkOdds: Int        = 5       // 1 in N blinks doubles
    var doubleBlinkGap: Double      = 0.18

    // Tap reaction
    var tapBounceScale: Double      = 1.08
    var tapHopHeight: Double        = 10
    var tapSpringResponse: Double   = 0.3
    var tapSpringDamping: Double    = 0.5

    // State transition
    var transitionDuration: Double  = 0.35
    var transitionPulseScale: Double = 0.96

    // Moments (eating after a log, ecstatic on streak milestones)
    var momentDuration: Double          = 2.5
    var momentBounceEating: Double      = 1.12
    var momentBounceEcstatic: Double    = 1.22
    var momentSpringResponse: Double    = 0.35
    var momentSpringDamping: Double     = 0.5

    static let `default` = MochiMotion()
}
