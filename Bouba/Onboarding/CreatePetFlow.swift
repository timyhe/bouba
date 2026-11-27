import SwiftUI
import PhotosUI

private struct RoutineSuggestion: Identifiable {
    let id: String
    let kind: TaskKind
    let title: String
    let hour: Int
    let minute: Int
    let amount: String
    var selectedByDefault = true

    var timeString: String { Date().at(hour: hour, minute: minute).timeString }

    static func forSpecies(_ species: Species) -> [RoutineSuggestion] {
        switch species {
        case .dog:
            return [
                .init(id: "potty-am", kind: .bathroom, title: "Morning potty", hour: 7, minute: 30, amount: ""),
                .init(id: "breakfast", kind: .food, title: "Breakfast", hour: 8, minute: 0, amount: "1 cup"),
                .init(id: "walk", kind: .walk, title: "Walk", hour: 12, minute: 0, amount: "30 min"),
                .init(id: "potty-pm", kind: .bathroom, title: "Afternoon potty", hour: 17, minute: 0, amount: ""),
                .init(id: "dinner", kind: .food, title: "Dinner", hour: 18, minute: 0, amount: "1 cup"),
                .init(id: "water", kind: .water, title: "Fresh water", hour: 19, minute: 0, amount: "", selectedByDefault: false),
                .init(id: "potty-bed", kind: .bathroom, title: "Bedtime potty", hour: 21, minute: 0, amount: ""),
                .init(id: "play", kind: .play, title: "Play time", hour: 15, minute: 0, amount: "20 min", selectedByDefault: false),
                .init(id: "meds", kind: .medication, title: "Medication", hour: 8, minute: 0, amount: "", selectedByDefault: false),
            ]
        case .cat:
            return [
                .init(id: "breakfast", kind: .food, title: "Breakfast", hour: 8, minute: 0, amount: "½ can"),
                .init(id: "dinner", kind: .food, title: "Dinner", hour: 18, minute: 0, amount: "½ can"),
                .init(id: "water", kind: .water, title: "Fresh water", hour: 9, minute: 0, amount: ""),
                .init(id: "litter", kind: .litter, title: "Scoop litter", hour: 9, minute: 0, amount: ""),
                .init(id: "play", kind: .play, title: "Play time", hour: 19, minute: 0, amount: "15 min"),
                .init(id: "brush", kind: .grooming, title: "Brushing", hour: 20, minute: 0, amount: "", selectedByDefault: false),
                .init(id: "meds", kind: .medication, title: "Medication", hour: 8, minute: 0, amount: "", selectedByDefault: false),
            ]
        case .other:
            return [
                .init(id: "feed", kind: .food, title: "Feed", hour: 8, minute: 0, amount: ""),
                .init(id: "water", kind: .water, title: "Fresh water", hour: 8, minute: 0, amount: ""),
                .init(id: "clean", kind: .custom, title: "Clean habitat", hour: 10, minute: 0, amount: "", selectedByDefault: false),
                .init(id: "play", kind: .play, title: "Play time", hour: 18, minute: 0, amount: "", selectedByDefault: false),
            ]
        }
    }
}

/// Friendly, mostly-tap pet profile setup (doc: "quick selections replacing typing").
struct CreatePetFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var isSheet = false

    @State private var step = 0
    /// True while stepping back, so pages slide in from the left.
    @State private var goingBack = false
    @State private var species: Species = .dog
    @State private var name = ""
    @State private var breed = ""
    @State private var age = 3
    @State private var size: PetSize = .medium
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var avatarColor = 0
    @State private var routine: Set<String> = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var permission: VetPermission = .callFirst
    @State private var showAIComingSoon = false
    @State private var invite = Caretaker(name: "", role: .temporary,
                                          color: [Color.purple, .pink, .teal, .indigo, .mint, .blue].randomElement() ?? .purple,
                                          notifyOnComplete: true, isPending: true)
    /// Set once the owner creates the invite link, so the caretaker is saved with the pet.
    @State private var inviteCreated = false
    @State private var linkCopied = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, breed }

    private let totalSteps = 7
    private enum StepID { static let invite = 5, share = 6 }
    private var inviteName: String { invite.name.trimmingCharacters(in: .whitespaces) }
    private var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "your pet" : trimmed
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(Color.boubaOrange)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .animation(.snappy, value: step)

            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                        .id(step)
                        .transition(reduceMotion ? .opacity
                                    : .asymmetric(insertion: .move(edge: goingBack ? .leading : .trailing).combined(with: .opacity),
                                                  removal: .move(edge: goingBack ? .trailing : .leading).combined(with: .opacity)))
                }
                .padding(24)
                // Room to scroll the last field above the floating button while the keyboard is up.
                .padding(.bottom, 72)
            }
            .scrollDismissesKeyboard(.interactively)
            // The button floats over the content, so fields scroll beneath it instead of being cut off by a band.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: primaryTitle) { advance() }
                    .disabled(primaryDisabled)
                    .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollEdgeEffectHidden(true, for: .bottom)
            // Keep the focused field clear of the keyboard and the floating button.
            .onChange(of: focusedField) { _, field in
                guard let field else { return }
                // Wait for the keyboard's own scroll adjustment, which would otherwise override this one.
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    withAnimation(.snappy) { proxy.scrollTo(field, anchor: UnitPoint(x: 0.5, y: 0.2)) }
                }
            }
            }
        }
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step > 0)
        .toolbar {
            if step > 0 {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        go(to: step - 1)
                    }
                    .tint(Color.primary)
                }
            }
            if step == StepID.invite {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { finish() }
                        .font(.allo(16, .semibold))
                        .tint(Color.primary)
                }
            }
            if isSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                        .tint(Color.primary)
                }
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    withAnimation { photo = image }
                }
            }
        }
        .onChange(of: species, initial: true) { _, newValue in
            routine = Set(RoutineSuggestion.forSpecies(newValue).filter(\.selectedByDefault).map(\.id))
        }
        .alert("Coming soon", isPresented: $showAIComingSoon) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Soon you'll be able to upload your notes or a doc, or let Bouba listen in on an intake call, and we'll fill this out for you.")
        }
    }

    private var primaryTitle: String {
        switch step {
        case StepID.invite: return "Create invite link"
        case StepID.share: return "Done"
        default: return "Continue"
        }
    }

    private var primaryDisabled: Bool {
        switch step {
        case 1: return name.trimmingCharacters(in: .whitespaces).isEmpty
        case StepID.invite: return inviteName.isEmpty
        default: return false
        }
    }

    private func advance() {
        if step == StepID.invite {
            invite.name = inviteName
            if invite.role == .coOwner { invite.canEditTasks = true }
            inviteCreated = true
        }
        if step < totalSteps - 1 {
            go(to: step + 1)
        } else {
            finish()
        }
    }

    /// Moves between steps. When the direction flips, the outgoing page needs one update with the
    /// new direction before it leaves, so the step changes on the next tick.
    private func go(to newStep: Int) {
        let back = newStep < step
        if back == goingBack {
            withAnimation(.snappy) { step = newStep }
        } else {
            goingBack = back
            Task { @MainActor in withAnimation(.snappy) { step = newStep } }
        }
    }

    private func finish() {
        let suggestions = RoutineSuggestion.forSpecies(species).filter { routine.contains($0.id) }
        var pet = Pet(
            name: name.trimmingCharacters(in: .whitespaces),
            species: species,
            breed: breed,
            age: age,
            size: size,
            photo: photo,
            color: Self.avatarColors[avatarColor],
            tasks: suggestions.map {
                CareTask(kind: $0.kind, title: $0.title, hour: $0.hour, minute: $0.minute, amount: $0.amount,
                         isTimeSensitive: $0.kind == .medication)
            },
            contacts: [Contact(name: store.ownerName, relation: "Owner", phone: "(917) 555-0101")]
        )
        pet.vet = VetInfo(clinic: vetName, phone: vetPhone, permission: permission)
        if inviteCreated { pet.caretakers.append(invite) }
        store.addPet(pet)
        if isSheet {
            dismiss()
        } else {
            store.startAsOwner()
        }
    }

    // MARK: Steps

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 0: speciesStep
        case 1: nameStep
        case 2: aboutStep
        case 3: routineStep
        case 4: emergencyStep
        case StepID.invite: inviteStep
        default: shareStep
        }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        title(text, Text(subtitle))
    }

    private func title(_ text: String, _ subtitle: Text? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.allo(32, .bold))
            if let subtitle {
                subtitle.font(.alloSubtext(18)).foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var speciesStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("Who are we\ncaring for?")

            HStack(spacing: 12) {
                ForEach(Species.allCases) { s in
                    Button {
                        species = s
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: s.symbol)
                                .font(.system(size: 38, weight: .semibold))
                                .foregroundStyle(species == s ? Color.boubaOrangeText : Color.primary)
                                .frame(height: 50)
                            Text(s.label).font(.allo(17, .semibold)).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .layeredShadow(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay {
                            if species == s {
                                RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.boubaOrangeText, lineWidth: 2.5)
                            }
                        }
                        // Colors and border snap; only the pop below animates.
                        .transaction { $0.animation = nil }
                    }
                    .buttonStyle(InstantSelectStyle())
                    .accessibilityAddTraits(species == s ? .isSelected : [])
                    .selectionPop(species == s)
                    .sensoryFeedback(.impact(weight: .light), trigger: species)
                }
            }

            Button { showAIComingSoon = true } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.purple)
                        .frame(width: 32)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Already have care notes?").font(.allo(16, .semibold)).foregroundStyle(.primary)
                        Text("Import a doc or record an intake call").font(.alloSubtext(16)).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Text("Soon").font(.allo(12, .semibold)).foregroundStyle(.purple)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.purple.opacity(0.12), in: Capsule())
                }
                .card(padding: 14)
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            title("What's their name?")

            HStack {
                Spacer()
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let photo {
                                Image(uiImage: photo).resizable().scaledToFill()
                            } else {
                                ZStack {
                                    Self.avatarColors[avatarColor]
                                    Image(systemName: species.symbol).font(.system(size: 52, weight: .semibold)).foregroundStyle(.white)
                                }
                            }
                        }
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())

                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(.systemGray))
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5), in: Circle())
                            // Solid ring drawn as a disc behind, so no fringe shows around it.
                            .padding(3)
                            .background(Color(.systemBackground), in: Circle())
                    }
                }
                .buttonStyle(PressableStyle())
                Spacer()
            }

            colorPicker

            TextField("Name", text: $name)
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { if !primaryDisabled { advance() } }
                // Big like the phone number field, since it's the one thing this step asks for.
                .font(.allo(20, .semibold))
                .fieldStyle()
                .id(Field.name)
        }
    }

    /// Avatar colors to pick from; orange (index 0) is the default.
    static let avatarColors: [Color] = [
        .boubaOrange,  // the accent orange
        Color(red: 1.0, green: 0.42, blue: 0.68),   // pink
        Color(red: 0.56, green: 0.40, blue: 0.95),  // purple
        Color(red: 0.20, green: 0.58, blue: 1.0),   // blue
        Color(red: 0.10, green: 0.68, blue: 0.70),  // teal
        Color(red: 0.20, green: 0.72, blue: 0.45),  // green
    ]

    private var colorPicker: some View {
        HStack(spacing: 14) {
            ForEach(Self.avatarColors.indices, id: \.self) { i in
                let selected = avatarColor == i
                Button {
                    avatarColor = i
                } label: {
                    Circle()
                        .fill(Self.avatarColors[i])
                        .frame(width: 32, height: 32)
                        .padding(4)
                        .overlay(
                            Circle().strokeBorder(selected ? Self.avatarColors[i] : .clear, lineWidth: 2.5)
                        )
                }
                .buttonStyle(InstantSelectStyle())
                .sensoryFeedback(.selection, trigger: avatarColor)
                .accessibilityLabel(["Orange", "Pink", "Purple", "Blue", "Teal", "Green"][i])
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var aboutStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            title("A little about \(displayName)")

            VStack(alignment: .leading, spacing: 12) {
                Text("Breed (optional)").font(.allo(17, .semibold))
                TextField("Goldendoodle", text: $breed)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .breed)
                    .submitLabel(.done)
                    .fieldStyle()
                    .id(Field.breed)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Age").font(.allo(17, .semibold))
                HStack {
                    Button { if age > 0 { age -= 1 } } label: {
                        Image(systemName: "minus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Color.primary)
                    .accessibilityLabel("Decrease age")
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(age)").font(.allo(44, .bold)).contentTransition(.numericText(value: Double(age)))
                        Text(age == 1 ? "year" : "years").font(.alloSubtext(16)).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    Button { if age < 30 { age += 1 } } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Color.primary)
                    .accessibilityLabel("Increase age")
                }
                .animation(.snappy, value: age)
                .sensoryFeedback(.selection, trigger: age)
                .card(padding: 14)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Size").font(.allo(17, .semibold))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(PetSize.allCases) { s in
                        Button {
                            size = s
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.label).font(.allo(17, .semibold)).foregroundStyle(.primary)
                                Text(s.detail).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .layeredShadow(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                if size == s {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.boubaOrangeText, lineWidth: 2.5)
                                }
                            }
                            // Colors and border snap; only the pop below animates.
                            .transaction { $0.animation = nil }
                        }
                        .buttonStyle(InstantSelectStyle())
                        .accessibilityAddTraits(size == s ? .isSelected : [])
                        .selectionPop(size == s)
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: size)
            }
        }
    }

    private var routineStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("What does a typical day look like?", "Tap to add. You can fine-tune times and details later.")

            VStack(spacing: 10) {
                ForEach(RoutineSuggestion.forSpecies(species)) { s in
                    let isOn = routine.contains(s.id)
                    Button {
                        if isOn { routine.remove(s.id) } else { routine.insert(s.id) }
                    } label: {
                        HStack(spacing: 14) {
                            IconTile(kind: s.kind, size: 42)
                                .saturation(isOn ? 1 : 0)
                                .opacity(isOn ? 1 : 0.5)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title).font(.allo(16, .semibold)).foregroundStyle(.primary)
                                Text([s.timeString, s.amount].filter { !$0.isEmpty }.joined(separator: " · "))
                                    .font(.alloSubtext(16))
                                    .foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(isOn ? Color.boubaOrangeText : Color(.systemGray))
                        }
                        .card(padding: 12, radius: 18)
                    }
                    .buttonStyle(InstantSelectStyle())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .sensoryFeedback(.impact(weight: .light), trigger: isOn)
                }
            }
        }
    }

    private var emergencyStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Just in case", Text("Caretakers can reach this anytime from the \(Image(systemName: "exclamationmark.triangle")) button."))

            VStack(spacing: 10) {
                TextField("Vet clinic", text: $vetName).fieldStyle()
                TextField("Vet phone", text: $vetPhone).keyboardType(.phonePad).fieldStyle()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("If \(displayName) seems unwell, a caretaker can…").font(.allo(17, .semibold))
                ForEach(VetPermission.allCases) { p in
                    Button {
                        permission = p
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: p.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.boubaOrangeText)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.label).font(.allo(16, .semibold)).foregroundStyle(.primary)
                                Text(p.detail).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: permission == p ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(permission == p ? Color.boubaOrangeText : Color(.systemGray))
                        }
                        .card(padding: 14, radius: 18)
                    }
                    .buttonStyle(InstantSelectStyle())
                    .accessibilityAddTraits(permission == p ? .isSelected : [])
                }
                .sensoryFeedback(.impact(weight: .light), trigger: permission)
            }
        }
    }

    // MARK: Invite

    private var inviteStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Invite someone to help?", "Share \(displayName)'s care with a sitter or co-owner. You can always do this later.")

            TextField("Their name", text: $invite.name)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .fieldStyle()

            VStack(spacing: 10) {
                ForEach([CaretakerRole.temporary, .coOwner]) { role in
                    Button {
                        invite.role = role
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: role.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(Color.boubaOrangeText)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.label).font(.allo(16, .semibold)).foregroundStyle(.primary)
                                Text(role.detail).font(.alloSubtext(15)).foregroundStyle(Color.textSecondary)
                            }
                            Spacer()
                            Image(systemName: invite.role == role ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(invite.role == role ? Color.boubaOrangeText : Color(.systemGray))
                        }
                        .card(padding: 14, radius: 18)
                    }
                    .buttonStyle(InstantSelectStyle())
                    .accessibilityAddTraits(invite.role == role ? .isSelected : [])
                }
                .sensoryFeedback(.impact(weight: .light), trigger: invite.role)
            }

            if invite.role == .temporary {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How long are they caring for \(displayName)?").font(.allo(17, .semibold))
                    RangeCalendar(start: $invite.start, end: $invite.end)
                    Text(sitterLength)
                        .font(.alloSubtext(15))
                        .foregroundStyle(Color.textSecondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.snappy, value: invite.role)
    }

    private var sitterLength: String {
        let days = (Calendar.current.dateComponents([.day], from: invite.start.startOfDay, to: invite.end.startOfDay).day ?? 0) + 1
        return "\(days) day\(days == 1 ? "" : "s"). Access ends automatically after \(invite.end.shortDay)."
    }

    // MARK: Share

    private var inviteMessage: String {
        "Hi \(inviteName)! I'm using Bouba to share everything about caring for \(displayName). Tap to join: \(invite.inviteURL.absoluteString)"
    }

    private var shareStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            title("Send \(inviteName) the link", "They'll meet \(displayName) and see everything you've set up.")

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("bouba.app/join/\(invite.inviteCode)")
                        .font(.allo(17, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(invite.role == .temporary ? "\(invite.role.label) · \(invite.accessSummary)" : invite.role.label)
                        .font(.alloSubtext(15))
                        .foregroundStyle(Color.textSecondary)
                }
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = invite.inviteURL.absoluteString
                    linkCopied = true
                } label: {
                    Image(systemName: linkCopied ? "checkmark" : "doc.on.doc.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(linkCopied ? "Invite link copied" : "Copy invite link")
                .sensoryFeedback(.success, trigger: linkCopied)
                ShareLink(item: invite.inviteURL,
                          subject: Text("Help care for \(displayName)"),
                          message: Text(inviteMessage)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.textSecondary)
                        .frame(width: 36, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share invite link")
            }
            .fieldStyle()
        }
    }
}

// MARK: - Date range calendar

/// A month calendar for picking a stay: tap the first day, then the last.
/// Tapping again starts a new range. Past days are unavailable.
private struct RangeCalendar: View {
    @Binding var start: Date
    @Binding var end: Date

    @State private var month: Date = Date().startOfMonth
    /// True after the first tap, while waiting for the last day.
    @State private var pickingEnd = false
    /// Which way the month grid slides: true when paging forward.
    @State private var pagingForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()))
                    .font(.allo(17, .semibold))
                Spacer()
                monthButton("chevron.left", label: "Previous month", offset: -1)
                    .disabled(month <= Date().startOfMonth)
                monthButton("chevron.right", label: "Next month", offset: 1)
            }

            VStack(spacing: 4) {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.allo(13, .semibold))
                            .foregroundStyle(Color.textSecondary)
                            .frame(maxWidth: .infinity)
                            .accessibilityHidden(true)
                    }
                }
                // Keyed by month so each page slides in from the side you paged toward.
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day { dayCell(day) } else { Color.clear.frame(height: 44) }
                    }
                }
                .id(month)
                .transition(monthTransition)
            }
            .clipped()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .background(Color.fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .sensoryFeedback(.selection, trigger: end)
    }

    private func monthButton(_ symbol: String, label: String, offset: Int) -> some View {
        Button {
            page(by: offset)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .accessibilityLabel(label)
    }

    private var monthTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: pagingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: pagingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func page(by offset: Int) {
        let target = calendar.date(byAdding: .month, value: offset, to: month) ?? month
        let forward = offset > 0
        let animation = Animation.spring(duration: 0.35, bounce: 0)
        if forward == pagingForward {
            withAnimation(animation) { month = target }
        } else {
            // Set the direction first so the leaving page uses it too.
            pagingForward = forward
            Task { @MainActor in withAnimation(animation) { month = target } }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isStart = calendar.isDate(day, inSameDayAs: start)
        let isEnd = calendar.isDate(day, inSameDayAs: end)
        let isEndpoint = isStart || isEnd
        let inRange = day > start.startOfDay && day < end.startOfDay
        let isPast = day < Date().startOfDay

        return Button {
            select(day)
        } label: {
            Text(day.formatted(.dateTime.day()))
                .font(.allo(16, isEndpoint ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isEndpoint ? Color.white : (isPast ? Color(.systemGray3) : Color.primary))
                .frame(width: 40, height: 40)
                .background {
                    if isEndpoint { Circle().fill(Color.boubaOrangeFill) }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                // A band joins the days in between, and runs halfway into each end.
                .background(alignment: .center) {
                    rangeBand(isStart: isStart, isEnd: isEnd, inRange: inRange)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isPast)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isEndpoint || inRange ? .isSelected : [])
    }

    @ViewBuilder
    private func rangeBand(isStart: Bool, isEnd: Bool, inRange: Bool) -> some View {
        let band = Color.boubaOrange.opacity(0.15)
        let hasRange = !calendar.isDate(start, inSameDayAs: end)
        if inRange {
            band.frame(height: 40)
        } else if hasRange && isStart {
            HStack(spacing: 0) { Color.clear; band }.frame(height: 40)
        } else if hasRange && isEnd {
            HStack(spacing: 0) { band; Color.clear }.frame(height: 40)
        }
    }

    private func select(_ day: Date) {
        if pickingEnd && day >= start.startOfDay {
            end = day
            pickingEnd = false
        } else {
            start = day
            end = day
            pickingEnd = true
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first]).enumerated().map { i, s in
            // Two days can share a letter (T, S), so keep the ids unique.
            s + String(repeating: "\u{200B}", count: i)
        }
    }

    /// The month's days, padded with blanks so the 1st lands under its weekday.
    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        let dates: [Date?] = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + dates
    }
}

private extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }
}
