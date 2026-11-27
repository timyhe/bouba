import SwiftUI
import UIKit

// MARK: - Roles

enum Role: String, CaseIterable, Identifiable {
    case owner, caretaker
    var id: String { rawValue }
}

// MARK: - Pet basics

enum Species: String, CaseIterable, Identifiable {
    case dog, cat, other
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .dog: return "dog.fill"
        case .cat: return "cat.fill"
        case .other: return "pawprint.fill"
        }
    }
}

enum PetSize: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "XL"
        }
    }
    var detail: String {
        switch self {
        case .small: return "Under 20 lb"
        case .medium: return "20–50 lb"
        case .large: return "50–90 lb"
        case .extraLarge: return "90+ lb"
        }
    }
}

// MARK: - Tasks

enum TaskKind: String, CaseIterable, Identifiable {
    case food, water, medication, bathroom, walk, play, litter, treat, grooming, custom
    var id: String { rawValue }

    var label: String {
        switch self {
        case .food: return "Food"
        case .water: return "Water"
        case .medication: return "Meds"
        case .bathroom: return "Potty"
        case .walk: return "Walk"
        case .play: return "Play"
        case .litter: return "Litter"
        case .treat: return "Treat"
        case .grooming: return "Groom"
        case .custom: return "Other"
        }
    }

    var defaultTitle: String {
        switch self {
        case .food: return "Feed"
        case .water: return "Fresh water"
        case .medication: return "Medication"
        case .bathroom: return "Potty break"
        case .walk: return "Walk"
        case .play: return "Play time"
        case .litter: return "Scoop litter"
        case .treat: return "Treats"
        case .grooming: return "Brushing"
        case .custom: return "Task"
        }
    }

    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .water: return "drop.fill"
        case .medication: return "pills.fill"
        case .bathroom: return "tree.fill"
        case .walk: return "figure.walk"
        case .play: return "tennisball.fill"
        case .litter: return "sparkles"
        case .treat: return "heart.fill"
        case .grooming: return "scissors"
        case .custom: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .food: return .petOrange
        case .water: return Color(red: 0.20, green: 0.58, blue: 1.0)
        case .medication: return Color(red: 0.95, green: 0.30, blue: 0.40)
        case .bathroom: return Color(red: 0.90, green: 0.66, blue: 0.10)
        case .walk: return Color(red: 0.20, green: 0.72, blue: 0.45)
        case .play: return Color(red: 0.56, green: 0.40, blue: 0.95)
        case .litter: return Color(red: 0.10, green: 0.68, blue: 0.70)
        case .treat: return Color(red: 1.0, green: 0.42, blue: 0.68)
        case .grooming: return Color(red: 0.36, green: 0.42, blue: 0.90)
        case .custom: return Color(.systemGray)
        }
    }

    /// One-tap answers a caretaker can attach when completing.
    var quickOptions: [String] {
        switch self {
        case .food: return ["Ate it all", "Ate some", "Didn't eat"]
        case .water: return ["Refilled", "Cleaned bowl"]
        case .medication: return ["Given", "Hidden in food", "Refused"]
        case .bathroom: return ["Pee", "Poop", "Both", "Nothing"]
        case .walk: return ["15 min", "30 min", "45 min", "1 hr"]
        case .play: return ["10 min", "20 min", "30 min"]
        case .litter: return ["Scooped", "Full change"]
        case .treat: return ["1 treat", "2 treats"]
        case .grooming: return ["Brushed", "Nails", "Bath"]
        case .custom: return []
        }
    }
}

struct Photo: Identifiable {
    let id = UUID()
    var image: UIImage? = nil
    /// Index into a set of built-in placeholder images (used for sample data).
    var sample: Int = 0
}

struct Completion: Identifiable {
    let id = UUID()
    var date: Date
    var by: String
    var option: String? = nil
    var note: String = ""
    var photo: Photo? = nil
}

struct CareTask: Identifiable {
    let id = UUID()
    var kind: TaskKind
    var title: String
    var hour: Int
    var minute: Int
    var amount: String = ""
    var instructions: String = ""
    var isTimeSensitive: Bool = false
    var completions: [Completion] = []

    var minutesOfDay: Int { hour * 60 + minute }
    var timeString: String { Date().at(hour: hour, minute: minute).timeString }

    func completion(on day: Date) -> Completion? {
        completions
            .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
            .max { $0.date < $1.date }
    }

    var lastCompletion: Completion? {
        completions.filter { $0.date <= Date() }.max { $0.date < $1.date }
    }

    /// Past due by more than 30 minutes on the given day, and not done.
    func isLate(on day: Date) -> Bool {
        guard completion(on: day) == nil else { return false }
        return day.at(hour: hour, minute: minute).adding(minutes: 30) < Date()
    }
}

// MARK: - Updates (photos, check-ins)

enum UpdateKind {
    case post, arrived, left
}

struct PetUpdate: Identifiable {
    let id = UUID()
    var date: Date
    var by: String
    var kind: UpdateKind = .post
    var text: String = ""
    var mood: String? = nil
    var photos: [Photo] = []

    static let moods = ["Happy", "Sleepy", "Ate well", "Playful", "Missing you", "Seems off"]

    static func moodSymbol(_ mood: String) -> String {
        switch mood {
        case "Happy": return "face.smiling"
        case "Sleepy": return "moon.zzz.fill"
        case "Ate well": return "fork.knife"
        case "Playful": return "tennisball.fill"
        case "Missing you": return "heart.fill"
        case "Seems off": return "thermometer.medium"
        default: return "sparkles"
        }
    }
}

// MARK: - Caretakers

enum CaretakerRole: String, CaseIterable, Identifiable {
    case coOwner, temporary, regular
    var id: String { rawValue }
    var label: String {
        switch self {
        case .coOwner: return "Co-owner"
        case .temporary: return "Pet sitter"
        case .regular: return "Regular sitter"
        }
    }
    var detail: String {
        switch self {
        case .coOwner: return "Shares care day to day. Always has access."
        case .temporary: return "Access for specific dates, like a trip."
        case .regular: return "Ongoing access for trusted friends who help often."
        }
    }
    var symbol: String {
        switch self {
        case .coOwner: return "person.2.fill"
        case .temporary: return "calendar.badge.clock"
        case .regular: return "heart.circle.fill"
        }
    }
}

enum PhotoFrequency: String, CaseIterable, Identifiable {
    case none, daily, everyVisit, lots
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "Not needed"
        case .daily: return "Once a day"
        case .everyVisit: return "Every visit"
        case .lots: return "As many as possible!"
        }
    }
}

enum CaretakerStatus {
    case pending, upcoming, active, ended
    var label: String {
        switch self {
        case .pending: return "Invite sent"
        case .upcoming: return "Upcoming"
        case .active: return "Active"
        case .ended: return "Ended"
        }
    }
    var color: Color {
        switch self {
        case .pending: return .boubaOrange
        case .upcoming: return .blue
        case .active: return .boubaGreen
        case .ended: return .gray
        }
    }
}

func makeInviteCode() -> String {
    let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    return String((0..<6).map { _ in chars.randomElement()! })
}

struct Caretaker: Identifiable {
    let id = UUID()
    var name: String
    var role: CaretakerRole
    var color: Color = .purple
    /// Name of a bundled portrait; falls back to initials when nil or missing.
    var photo: String? = nil
    var start: Date = Date().startOfDay
    var end: Date = Date().startOfDay.adding(days: 3)
    var earlyAccessDays: Int = 3
    var notifyOnComplete: Bool = false
    var photoFrequency: PhotoFrequency = .daily
    var checkInOut: Bool = false
    var canEditTasks: Bool = false
    var showHomeAccess: Bool = true
    var isPending: Bool = false
    var inviteCode: String = makeInviteCode()

    var inviteURL: URL { URL(string: "https://bouba.app/join/\(inviteCode)")! }

    var accessSummary: String {
        role == .temporary ? "\(start.shortDay) – \(end.shortDay)" : "Always"
    }

    func isActive(on day: Date) -> Bool {
        if isPending { return false }
        guard role == .temporary else { return true }
        return day.startOfDay >= start.startOfDay && day.startOfDay <= end.startOfDay
    }

    var status: CaretakerStatus {
        if isPending { return .pending }
        guard role == .temporary else { return .active }
        let today = Date().startOfDay
        if today < start.startOfDay { return .upcoming }
        if today > end.startOfDay { return .ended }
        return .active
    }
}

// MARK: - Pet profile

struct HomeAccess {
    var address = ""
    var entry = ""
    var code = ""
    var wifiName = ""
    var wifiPassword = ""
    var notes = ""
}

enum VetPermission: String, CaseIterable, Identifiable {
    case anytime, callFirst, emergencyOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .anytime: return "Take to the vet anytime"
        case .callFirst: return "Call me first"
        case .emergencyOnly: return "Emergencies only"
        }
    }
    var detail: String {
        switch self {
        case .anytime: return "You don't need to ask before taking them in."
        case .callFirst: return "Reach the owner before any vet visit."
        case .emergencyOnly: return "Only go without asking if it's urgent."
        }
    }
    var symbol: String {
        switch self {
        case .anytime: return "checkmark.shield.fill"
        case .callFirst: return "phone.badge.waveform.fill"
        case .emergencyOnly: return "light.beacon.max.fill"
        }
    }
}

struct VetInfo {
    var clinic = ""
    var phone = ""
    var address = ""
    var permission: VetPermission = .callFirst
}

struct Contact: Identifiable {
    let id = UUID()
    var name: String
    var relation: String
    var phone: String
}

struct InstructionNote: Identifiable {
    let id = UUID()
    var title: String
    var body: String
    var symbol: String = "info.circle.fill"
}

struct Pet: Identifiable {
    let id = UUID()
    var name: String
    var species: Species
    var breed: String = ""
    var age: Int = 3
    var size: PetSize = .medium
    var photo: UIImage? = nil
    var color: Color = .boubaOrange
    var tasks: [CareTask] = []
    var notes: [InstructionNote] = []
    var mustNotEat: [String] = []
    var medical: String = ""
    var home = HomeAccess()
    var vet = VetInfo()
    var contacts: [Contact] = []
    var caretakers: [Caretaker] = []
    var updates: [PetUpdate] = []

    var subtitle: String {
        [breed.isEmpty ? species.label : breed, "\(age) yr\(age == 1 ? "" : "s")", size.label]
            .joined(separator: " · ")
    }
}

// MARK: - Notifications

struct AppNotification: Identifiable {
    let id = UUID()
    var date: Date
    var symbol: String
    var color: Color
    var title: String
    var body: String
}
