import SwiftUI

// MARK: - Single source of truth for Mochi's artwork
//
// Pure data: maps each state to its base image and optional blink frame.
// No view hardcodes an image string; adding a future state means touching
// only this file. Rendering (breathing, blinking, moments) lives in
// MochiView.

enum MochiAssetProvider {

    static func baseImageName(for state: MochiState) -> String {
        switch state {
        case .ecstatic:   return "mochi_ecstatic"
        case .happy:      return "mochi_happy"
        case .content:    return "mochi_content"
        case .sleepy:     return "mochi_sleepy"
        case .missingYou: return "mochi_missing"
        }
    }

    /// Only states whose art has open eyes get a blink frame; the rest
    /// have closed or occluded eyes and never blink.
    static func blinkImageName(for state: MochiState) -> String? {
        switch state {
        case .happy:      return "mochi_happy_blink"
        case .missingYou: return "mochi_missing_blink_aligned"
        default:          return nil
        }
    }

    /// Shown briefly after a successful food log.
    static let eatingImageName = "mochi_eating"

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
