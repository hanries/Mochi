import Foundation

// MARK: - Mochi's string bank
//
// Tone rules baked into the data: warm, never judgmental, never guilt-based,
// and no line anywhere references calories, macros, or amounts eaten.

enum MochiDialogue {

    static let lines: [MochiState: [String]] = [
        .ecstatic: [
            "You're on a roll! I'm so proud of you!",
            "Best streak buddies ever!",
            "Look at us go! 🎉",
            "I could do a backflip right now. I won't. But I could.",
            "You keep showing up and it makes my whole day.",
            "We make a great team, you and me.",
        ],
        .happy: [
            "Yum! Thanks for telling me about your meal.",
            "You logged today — that makes me happy!",
            "I love hearing about your day.",
            "A little note about a meal goes a long way!",
            "You're taking such good care of us.",
            "That's the spirit! One meal at a time.",
        ],
        .content: [
            "Hi there! I'm happy to see you.",
            "Just nibbling on a sunflower seed. How are you?",
            "It's a good day to be a hamster.",
            "I'm here whenever you want to log something.",
            "No rush. I'm just glad you stopped by.",
            "Stretching my little legs. Want to log a meal together?",
        ],
        .sleepy: [
            "Getting a bit cozy over here…",
            "*yawns* Long day, huh?",
            "I'm winding down. Still time for a quick log if you like.",
            "The evening is so peaceful, isn't it?",
            "I saved you a spot by the wood shavings.",
        ],
        .missingYou: [
            "You're back! I missed you!",
            "I was wondering how you've been!",
            "So good to see you again!",
            "I kept your spot warm.",
            "No matter how long it's been, I'm always happy you came.",
        ],
    ]

    static let celebrations: [String] = [
        "Yum!! Thank you!",
        "Yay! Logged it!",
        "Nom nom — got it!",
        "That's one for the books!",
        "You showed up. That's what counts!",
        "Another meal noted. You're doing great!",
        "Mochi approves! 🐹",
    ]

    /// Valueless acknowledgments for check-in events (weight logs etc.).
    /// Tone rule: never reference numbers, direction, body, or results —
    /// only the act of showing up.
    static let checkIns: [String] = [
        "Thanks for checking in!",
        "You showed up — that's the whole job.",
        "Noted! I'm glad you're here.",
        "Little habits, big cozy life.",
        "Check-in received. Carry on! 🐹",
    ]

    /// Tap reactions — each line matches the pose Mochi strikes when tapped.
    static let reactions: [MochiAssetProvider.Reaction: [String]] = [
        .wave: [
            "Oh, hi there! 👋",
            "*waves a little paw*",
            "Hellooo! Fancy seeing you here.",
            "Hi hi! You found me!",
        ],
        .scratch: [
            "Hmm… now what was I doing?",
            "*scratches head* Big thoughts happening.",
            "Wait, did I bury that seed somewhere?",
            "Thinking cap: officially on. 🤔",
        ],
        .love: [
            "I love you THIS much! 💕",
            "You're my favorite human, you know.",
            "*heart eyes* Just looking at my pal.",
            "Squish! Consider yourself hugged.",
        ],
        .peek: [
            "Eep! You startled me! 👀",
            "Oh! Didn't see you there.",
            "What's that?! …oh, it's just you. Phew.",
            "Peekaboo! Caught me mid-snoop.",
        ],
        .munch: [
            "Nom nom nom… 🌰",
            "Cheeks at maximum capacity!",
            "Just a little snack, don't mind me.",
            "*muffled* …want some? No? More for me!",
        ],
    ]

    static let notifications: [String] = [
        "Mochi is wondering what you had for lunch 🐹",
        "Mochi would love to hear about your day 🐹",
        "A little hamster says hi! Got a meal to share?",
        "Mochi is curious what's cooking 🐹",
        "Whenever you're ready, Mochi's all ears 🐹",
    ]

    /// Picks a line for a state, avoiding the most recently shown ones.
    static func line(for state: MochiState, excluding recent: [String] = []) -> String {
        let pool = lines[state] ?? []
        let fresh = pool.filter { !recent.contains($0) }
        return (fresh.isEmpty ? pool : fresh).randomElement() ?? "Hi there!"
    }

    static func celebrationLine() -> String {
        celebrations.randomElement() ?? "Yay!"
    }

    static func checkInLine() -> String {
        checkIns.randomElement() ?? "Thanks for checking in!"
    }

    /// A line that matches the reaction pose Mochi just played when tapped.
    static func line(for reaction: MochiAssetProvider.Reaction) -> String {
        (reactions[reaction] ?? []).randomElement() ?? "Hi there!"
    }

    static func notificationLine() -> String {
        notifications.randomElement() ?? "Mochi says hi 🐹"
    }
}
