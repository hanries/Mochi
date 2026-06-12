import Foundation

// MARK: - A short, transient Mochi performance
//
// Published by MochiViewModel when something worth reacting to happens.
// .eating plays after every successful food log; .ecstatic is reserved
// for streak milestones. MochiView temporarily overrides its displayed
// frame for the moment's duration, then returns to the engine-driven
// state. Driven by engagement only — never by calorie outcomes.

struct MochiMoment: Identifiable, Equatable {
    enum Kind {
        case eating
        /// Streak milestones only — never routine logs.
        case ecstatic
        /// Valueless acknowledgment (e.g. a weight log). No frame change,
        /// no tab switch — just a warm line and a small bounce. The event
        /// carries no value by design: Mochi cannot react to outcomes.
        case checkIn
    }

    let id = UUID()
    let kind: Kind
    let line: String
}
