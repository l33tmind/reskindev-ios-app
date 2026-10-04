import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Create / edit a service (website /profile/gigs/edit/[id])
struct GigEditorView: View {
    let gigID: String?

    @Environment(SellerStore.self) private var seller
    @Environment(SessionStore.self) private var session
    @Environment(GigStore.self) private var gigStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = GigDraft()
    @State private var loading = true
    @State private var saving = false
    @State private var photoItem: PhotosPickerItem?
    @State private var newImage: UIImage?
    @State private var newModel: URL?
    @State private var pickingModel = false
    @State private var keywordInput = ""
    @State private var featureInput = ""
    @State private var errorMessage: String?
    @State private var agreedToTerms = false

    /// The iOS app's declaration, word for word
    static let ugcDeclaration = "I confirm this video is uploaded as \"Unlisted\" on YouTube. I acknowledge that I am submitting User-Generated Content (UGC) and warrant that I own all intellectual property rights to this video. I agree not to submit any copyrighted, objectionable, or abusive material. I grant Reskindev permission to embed this video and assume full legal liability for its content."
    static let termsText = "I agree to the Terms of Service and confirm this service contains no abusive, copyright-infringing, or objectionable content."

    private var hasMedia: Bool {
        newImage != nil || !draft.imageUrl.isEmpty || !draft.youtubeUrl.trimmed.isEmpty
    }

    private static let defaultCategories = ["Service", "Design", "Development", "Writing", "Video & Animation", "Others"]
    private var categories: [String] {
        let list = gigStore.categories.isEmpty ? Self.defaultCategories : gigStore.categories
        return list.contains(draft.category) ? list : list + [draft.category]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(gigID == nil ? "Create New Gig" : "Edit Gig").font(.extraLargeTitle2.weight(.bold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Label("Save & Submit", systemImage: "checkmark") }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGreen)
                .disabled(saving || loading || !agreedToTerms)
                .help(agreedToTerms ? "Send for admin approval" : "Accept the Terms of Service below first")
            }
            .padding(28)

            if loading {
                ProgressView().frame(maxHeight: .infinity)
            } else {
                ScrollView { form.padding(.horizontal, 28).padding(.bottom, 28) }
            }
        }
        .frame(width: 1000, height: 820)
        // Flattens Explore's floating cards so they stay behind this sheet
        .sheetPresence()
        .task { await load() }
        .onChange(of: photoItem) { Task { await loadPhoto() } }
        .fileImporter(isPresented: $pickingModel, allowedContentTypes: [.usdz]) { result in
            if case .success(let url) = result { newModel = url }
        }
        .errorAlert("Couldn't save gig", message: $errorMessage)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 26) {
            Label("Every save is reviewed by the Reskindev admin before it goes live.", systemImage: "checkmark.shield")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            section("Basics") {
                GlassField(title: "Gig title", text: $draft.title, prompt: "I will develop an iOS app for you")
                Picker("Category", selection: $draft.category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                GlassField(title: "Description", text: $draft.descriptionText, axis: .vertical)
                keywordsEditor
            }

            section("Media") {
                Text("Add a picture, a YouTube video, or both. With only a video, its YouTube thumbnail becomes the cover.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    Group {
                        if let newImage {
                            Image(uiImage: newImage).resizable().scaledToFill()
                        } else if !draft.imageUrl.isEmpty {
                            CachedImage(url: draft.imageUrl)
                        } else {
                            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.white.opacity(0.06))
                        }
                    }
                    .frame(width: 260, height: 146)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.small))

                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(draft.imageUrl.isEmpty && newImage == nil ? "Choose Image" : "Change Image", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                        Text("Up to 5 MB. Bigger photos are compressed automatically.")
                            .font(.caption).foregroundStyle(.secondary)
                        if newImage != nil || !draft.imageUrl.isEmpty {
                            Button(role: .destructive) {
                                newImage = nil
                                photoItem = nil
                                draft.imageUrl = ""
                            } label: {
                                Label("Remove Picture", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                GlassField(title: "YouTube Video URL (Optional)", text: $draft.youtubeUrl, prompt: "e.g. https://youtu.be/...")
                // Same declaration as the iOS app, required whenever there's a picture or a video
                if hasMedia {
                    Toggle(isOn: $draft.videoConsent) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mandatory UGC & Copyright Declaration")
                                .font(.headline).foregroundStyle(.red)
                            Text(Self.ugcDeclaration).font(.callout)
                        }
                    }
                    .toggleStyle(CheckboxToggle())
                    .padding(14)
                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.small))
                    .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(Color.red.opacity(0.3)))
                }
            }

            section("3D Model (optional)") {
                HStack(spacing: 16) {
                    Image(systemName: "cube.transparent.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.brandGreen)
                        .frame(width: 80, height: 80)
                        .background(Color.brandGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.small))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(newModel?.lastPathComponent ?? (draft.model3dUrl.isEmpty ? "No model yet" : "3D model attached"))
                            .font(.headline)
                        Text("Upload a .usdz (up to 50 MB). Buyers on Apple Vision Pro can place it in their room.")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button {
                                pickingModel = true
                            } label: {
                                Label(draft.model3dUrl.isEmpty && newModel == nil ? "Choose .usdz" : "Replace", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            if !draft.model3dUrl.isEmpty || newModel != nil {
                                Button(role: .destructive) {
                                    newModel = nil
                                    draft.model3dUrl = ""
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            section("Packages") {
                // One, two or three packages (iOS app: at least one, at most three)
                HStack {
                    Text("\(draft.packages.count) of 3 packages").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    if draft.packages.count < 3 {
                        Button {
                            withAnimation { draft.addPackage() }
                        } label: {
                            Label("Add Package", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    ForEach($draft.packages) { $pkg in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Name", text: $pkg.name).font(.headline).textFieldStyle(.roundedBorder)
                                if draft.packages.count > 1 {
                                    Button(role: .destructive) {
                                        withAnimation { draft.removePackage(id: pkg.id) }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Remove this package")
                                }
                            }
                            HStack {
                                Text("$")
                                TextField("Price", value: $pkg.price, format: .number).textFieldStyle(.roundedBorder)
                            }
                            Stepper("\(pkg.deliveryDays) day delivery", value: $pkg.deliveryDays, in: 1...90)
                                .font(.subheadline)
                            TextField("What's included", text: $pkg.description, axis: .vertical)
                                .lineLimit(2...5)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.small))
                    }
                }
            }

            section("Feature Comparison") {
                HStack {
                    TextField("Add a feature (e.g. Source code)", text: $featureInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addFeature)
                    Button("Add", action: addFeature).buttonStyle(.bordered).disabled(featureInput.trimmed.isEmpty)
                }
                if !draft.masterFeatures.isEmpty {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                        GridRow {
                            Text("Feature").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            ForEach(draft.packages) { Text($0.name).font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                            Color.clear.frame(width: 1, height: 1)
                        }
                        ForEach(draft.masterFeatures.indices, id: \.self) { f in
                            GridRow {
                                Text(draft.masterFeatures[f])
                                ForEach(draft.packages.indices, id: \.self) { p in
                                    Toggle("", isOn: Binding(get: { draft.isChecked(package: p, feature: f) },
                                                             set: { _ in draft.toggle(package: p, feature: f) }))
                                        .labelsHidden()
                                        .accessibilityLabel("\(draft.masterFeatures[f]) in \(draft.packages[p].name)")
                                }
                                Button(role: .destructive) { draft.removeFeature(at: f) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove \(draft.masterFeatures[f])")
                            }
                        }
                    }
                }
            }

            // Terms of Service, required before submitting (iOS app)
            Toggle(isOn: $agreedToTerms) {
                Text(Self.termsText).font(.callout)
            }
            .toggleStyle(CheckboxToggle())
            .padding(16)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.small))
        }
    }

    /// A tick box with the text beside it
    struct CheckboxToggle: ToggleStyle {
        func makeBody(configuration: Configuration) -> some View {
            Button {
                configuration.isOn.toggle()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(configuration.isOn ? Color.brandGreen : .secondary)
                    configuration.label
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isOn ? "Checked" : "Unchecked")
        }
    }

    private var keywordsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keywords (up to 5)").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                ForEach(draft.keywords, id: \.self) { word in
                    Button {
                        draft.keywords.removeAll { $0 == word }
                    } label: {
                        Label(word, systemImage: "xmark").labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Remove keyword \(word)")
                }
                if draft.keywords.count < 5 {
                    TextField("Add keyword", text: $keywordInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .onSubmit(addKeyword)
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.title3.weight(.bold))
            content()
        }
        .padding(22)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Radius.medium))
    }

    // MARK: Actions

    private func addKeyword() {
        let word = keywordInput.trimmed
        if !word.isEmpty, !draft.keywords.contains(word), draft.keywords.count < 5 { draft.keywords.append(word) }
        keywordInput = ""
    }

    private func addFeature() {
        draft.addFeature(featureInput)
        featureInput = ""
    }

    private func load() async {
        defer { loading = false }
        guard let gigID else { return }
        do { draft = try await seller.loadDraft(id: gigID) } catch { errorMessage = error.localizedDescription }
    }

    private func loadPhoto() async {
        guard let data = try? await photoItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        newImage = image
    }

    private func save() async {
        guard hasMedia else {
            errorMessage = "Add a picture or a YouTube video."
            return
        }
        guard draft.videoConsent else {
            errorMessage = "You must accept the Mandatory UGC & Copyright Declaration."
            return
        }
        saving = true
        do {
            try await seller.save(draft, newImage: newImage, newModel: newModel, session: session)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        saving = false
    }
}
