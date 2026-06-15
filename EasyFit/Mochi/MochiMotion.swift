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

    // Sleepy blinking — slower, heavier, longer-held than an alert blink so
    // Mochi reads as drowsy-but-alive rather than a frozen closed frame.
    var sleepyBlinkInterval: ClosedRange<Double> = 2.2...4.0
    var sleepyBlinkDuration: Double = 0.6

    // Drifting "z" sleep overlay (rises and fades on a slow loop)
    var sleepyZPeriod: Double       = 3.0     // seconds per z rise/fade cycle
    var sleepyZCount: Int           = 3       // staggered z's in flight
    var sleepyZRise: Double         = 0.16    // fraction of size each z floats up
    var sleepyZOpacity: Double      = 0.55    // peak opacity of a z

    // Tap reaction
    var tapBounceScale: Double      = 1.08
    var tapHopHeight: Double        = 10
    var tapSpringResponse: Double   = 0.3
    var tapSpringDamping: Double    = 0.5
    var reactionDuration: Double    = 1.3     // how long a tapped reaction frame holds

    // State transition
    var transitionDuration: Double  = 0.35
    var transitionPulseScale: Double = 0.96

    // Habitat day/night window (minutes from midnight) + crossfade
    var habitatNightStartMinutes: Int = 19 * 60      // 19:00
    var habitatDayStartMinutes: Int   = 6 * 60 + 30  // 06:30
    var habitatCrossfade: Double      = 1.0

    // Tab bar (custom): content swap, sliding indicator, tapped-icon bounce
    var tabContentResponse: Double  = 0.32
    var tabContentDamping: Double   = 0.85
    var tabIndicatorResponse: Double = 0.35
    var tabIndicatorDamping: Double = 0.75
    var tabIconBounceScale: Double  = 1.18
    var tabIconBounceResponse: Double = 0.30
    var tabIconBounceDamping: Double = 0.45

    // Guided tour: Mochi walking between steps + the closing cross-fade
    var tourMoveResponse: Double    = 0.55
    var tourMoveDamping: Double     = 0.78
    var tourFadeOut: Double         = 0.5    // overlay cross-fade onto home Mochi

    // Cheer jump (weight / photo logs): Mochi springs up a few times for joy.
    var cheerJumpFraction: Double   = 0.13   // jump height ÷ Mochi's size
    var cheerJumpCount: Int         = 3
    var cheerUpResponse: Double     = 0.17   // spring up
    var cheerDownResponse: Double   = 0.22   // spring back down
    var cheerHangTime: Double       = 0.16   // held near the apex
    var cheerLandTime: Double       = 0.12   // pause between hops
    var cheerScale: Double          = 1.06   // slight grow mid-air

    // Moments (eating after a log, ecstatic on streak milestones)
    var momentDuration: Double          = 2.5
    var momentBounceEating: Double      = 1.12
    var momentBounceEcstatic: Double    = 1.22
    var momentSpringResponse: Double    = 0.35
    var momentSpringDamping: Double     = 0.5

    static let `default` = MochiMotion()
}
