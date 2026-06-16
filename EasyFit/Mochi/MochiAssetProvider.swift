import SwiftUI
import UIKit

// MARK: - Single source of truth for Mochi's artwork
//
// Pure data: maps each state to its base image and optional blink frame.
// No view hardcodes an image string; adding a future state means touching
// only this file. Rendering (breathing, blinking, moments) lives in
// MochiView.

enum MochiAssetProvider {

    /// The standalone closed-eye "peaceful" frame (originally drawn for
    /// `.content`). It's no longer a base frame for any state — `.content`
    /// is awake now — so it's reused as the eyes-shut frame for sleepy's
    /// slow blink. Roadmap: a dedicated `mochi_sleepy_blink`.
    static let eyesShutFrame = "mochi_content"

    static func baseImageName(for state: MochiState) -> String {
        switch state {
        case .ecstatic:   return "mochi_ecstatic"
        case .happy:      return "mochi_happy"
        // `.content` is an awake, calm mood. Its original art was eyes-closed
        // and read as "asleep" on launch (content is the default/brand-new/
        // daytime state), so it reuses the open-eyed happy frame until
        // dedicated open-eyed content art exists.
        case .content:    return "mochi_happy"
        case .sleepy:     return "mochi_sleepy"
        case .missingYou: return "mochi_missing"
        }
    }

    /// Open-eyed states get a blink frame so they feel alive. `.sleepy` blinks
    /// too — slowly and heavily (see MochiMotion.sleepyBlink*) using the
    /// eyes-shut frame; the rest without art return nil and never blink.
    static func blinkImageName(for state: MochiState) -> String? {
        switch state {
        case .happy:      return "mochi_happy_blink"
        case .content:    return "mochi_happy_blink"
        case .sleepy:     return eyesShutFrame
        case .missingYou: return "mochi_missing_blink_aligned"
        default:          return nil
        }
    }

    /// Shown briefly after a successful food log.
    static let eatingImageName = "mochi_eating"

    /// The "jumping for joy" frame for cheer moments (weight / photo logs).
    /// Prefers a dedicated `mochi_jump`; falls back to the excited frame until
    /// you add it — no code change needed when the art lands.
    static var cheerImageName: String {
        UIImage(named: "mochi_jump") != nil ? "mochi_jump" : "mochi_ecstatic"
    }

    // MARK: - Tap reactions (a random little performance when Mochi is tapped)
    //
    // The pool auto-includes only reactions whose dedicated art exists, so
    // dropping in e.g. `mochi_scratch` lights it up with zero code change.
    // Until art lands, tapping still bounces and waves (mochi_wave exists).
    enum Reaction: CaseIterable {
        case wave, scratch, love, peek, munch

        var assetName: String {
            switch self {
            case .wave:    return "mochi_wave"      // waving
            case .scratch: return "mochi_scratch"   // scratching head
            case .love:    return "mochi_love"      // hearts / adoring
            case .peek:    return "mochi_peek"      // wide-eyed surprised
            case .munch:   return "mochi_munch"     // stuffing cheeks
            }
        }
    }

    /// Tap reactions whose art is currently in the bundle.
    static func availableTapReactions() -> [Reaction] {
        Reaction.allCases.filter { UIImage(named: $0.assetName) != nil }
    }

    // MARK: - Presentation poses (guided tour)
    //
    // Poses are a PRESENTATION concern, deliberately separate from MochiState
    // (which stays engagement-only). Each maps to its dedicated tour frame.
    enum Pose { case wave, point, talk, sit }

    static func poseImageName(_ pose: Pose) -> String {
        switch pose {
        case .wave:  return "mochi_wave"
        case .point: return "mochi_point"
        case .talk:  return "mochi_talk"
        case .sit:   return "mochi_sit_down"
        }
    }

    /// The room illustration behind Mochi on the Home tab.
    static func habitatImageName(night: Bool) -> String {
        night ? "habitat_night" : "habitat_day"
    }

    static func tint(for state: MochiState) -> Color {
        switch state {
        case .ecstatic:   return Color(red: 1.0, green: 0.72, blue: 0.30)  // warm gold
        case .happy:      return Color(red: 1.0, green: 0.62, blue: 0.45)  // peach
        case .content:    return Color(red: 0.85, green: 0.72, blue: 0.55) // soft tan
        case .sleepy:     return Color(red: 0.62, green: 0.60, blue: 0.85) // dusk lavender
        case .missingYou: return Color(red: 0.95, green: 0.55, blue: 0.60) // soft rose
        }
    }
}
