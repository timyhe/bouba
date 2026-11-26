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
    var isSheet = false

    @State private var step = 0
    @State private var species: Species = .dog
    @State private var name = ""
    @State private var breed = ""
    @State private var age = 3
    @State private var size: PetSize = .medium
    @State private var photo: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var routine: Set<String> = []
    @State private var vetName = ""
    @State private var vetPhone = ""
    @State private var permission: VetPermission = .callFirst
    @State private var showAIComingSoon = false

    private let totalSteps = 5
    private var displayName: String { name.isEmpty ? "your pet" : name }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(totalSteps))
                .tint(Color.boubaOrange)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .animation(.snappy, value: step)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                        .id(step)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            // The button floats over the content, so fields scroll beneath it instead of being cut off by a band.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: step == totalSteps - 1 ? "Create \(displayName)'s profile" : "Continue") {
                    advance()
                }
                .disabled(step == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }
            .scrollEdgeEffectHidden(true, for: .bottom)
        }
        .background(OnboardingBackground())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step > 0)
        .toolbar {
            if step > 0 {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back", systemImage: "chevron.left") {
                        withAnimation(.snappy) { step -= 1 }
                    }
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

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.snappy) { step += 1 }
        } else {
            finish()
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
            color: [Color.boubaOrange, .teal, .pink, .indigo].randomElement() ?? .boubaOrange,
            tasks: suggestions.map {
                CareTask(kind: $0.kind, title: $0.title, hour: $0.hour, minute: $0.minute, amount: $0.amount,
                         isTimeSensitive: $0.kind == .medication)
            },
            contacts: [Contact(name: store.ownerName, relation: "Owner", phone: "(917) 555-0101")]
        )
        pet.vet = VetInfo(clinic: vetName, phone: vetPhone, permission: permission)
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
        default: emergencyStep
        }
    }

    private func title(_ text: String, _ subtitle: String) -> some View {
        title(text, Text(subtitle))
    }

    private func title(_ text: String, _ subtitle: Text? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text).font(.allo(32, .bold))
            if let subtitle {
                subtitle.font(.alloSubtext(18)).foregroundStyle(.secondary)
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
                                .foregroundStyle(species == s ? Color.boubaOrange : Color.primary)
                                .frame(height: 50)
                            Text(s.label).font(.allo(17, .semibold)).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(species == s ? Color.boubaOrange : Color.cardStroke, lineWidth: species == s ? 2.5 : 1)
                        )
                        // Colors and border snap; only the pop below animates.
                        .transaction { $0.animation = nil }
                    }
                    .buttonStyle(InstantSelectStyle())
                    .selectionPop(species == s)
                    .sensoryFeedback(.impact(weight: .light), trigger: species)
                }
            }

            Button { showAIComingSoon = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.purple, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Already have care notes?").font(.allo(16, .semibold)).foregroundStyle(.primary)
                        Text("Import a doc or record an intake call").font(.alloSubtext(16)).foregroundStyle(.secondary)
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
                                    Color.fieldFill
                                    Image(systemName: species.symbol).font(.system(size: 52, weight: .semibold)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())

                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.boubaOrange, in: Circle())
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    }
                }
                .buttonStyle(PressableStyle())
                Spacer()
            }

            VStack(spacing: 20) {
                TextField("Name", text: $name)
                    .font(.allo(22, .semibold))
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
                TextField("Breed (optional)", text: $breed)
                    .font(.allo(22, .semibold))
                    .textInputAutocapitalization(.words)
                    .fieldStyle()
            }
        }
    }

    private var aboutStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            title("A little about \(displayName)")

            VStack(alignment: .leading, spacing: 12) {
                Text("Age").font(.allo(17, .semibold))
                HStack {
                    Button { if age > 0 { age -= 1 } } label: {
                        Image(systemName: "minus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Color.primary)
                    Spacer()
                    VStack(spacing: 0) {
                        Text("\(age)").font(.allo(44, .bold)).contentTransition(.numericText(value: Double(age)))
                        Text(age == 1 ? "year" : "years").font(.alloSubtext(16)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { if age < 30 { age += 1 } } label: {
                        Image(systemName: "plus").font(.system(size: 18, weight: .bold)).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .tint(Color.primary)
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
                                Text(s.detail).font(.alloSubtext(15)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(size == s ? Color.boubaOrange : Color.cardStroke, lineWidth: size == s ? 2.5 : 1)
                            )
                        }
                        .buttonStyle(InstantSelectStyle())
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
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                                .font(.system(size: 24))
                                .foregroundStyle(isOn ? Color.boubaOrange : Color(.systemGray3))
                        }
                        .card(padding: 12, radius: 18)
                    }
                    .buttonStyle(InstantSelectStyle())
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
                                .foregroundStyle(Color.boubaOrange)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.label).font(.allo(16, .semibold)).foregroundStyle(.primary)
                                Text(p.detail).font(.alloSubtext(15)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: permission == p ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(permission == p ? Color.boubaOrange : Color(.systemGray3))
                        }
                        .card(padding: 14, radius: 18)
                    }
                    .buttonStyle(InstantSelectStyle())
                }
                .sensoryFeedback(.impact(weight: .light), trigger: permission)
            }
        }
    }
}
