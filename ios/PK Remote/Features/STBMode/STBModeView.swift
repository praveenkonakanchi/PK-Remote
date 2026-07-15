import SwiftUI

struct STBModeView: View {
    enum UtilityAction: Equatable {
        case remote(RemoteCommand)
        case keyboard
    }

    static let utilityActions: [UtilityAction] = [
        .remote(.home), .remote(.back), .keyboard, .remote(.menu)
    ]

    let appState: AppState
    @State private var isKeyboardPresented = false
    @State private var isAddingShortcut = false
    @State private var shortcutBeingEdited: RemoteAppShortcut?
    @State private var commandError: String?
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var isVisible = false

    private let actions: [(command: RemoteCommand, title: String, color: Color)] = [
        (.view, "View", .red),
        (.sort, "Sort", .green),
        (.favorites, "Favorites", .yellow),
        (.find, "Find", .blue)
    ]

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let sectionSpacing = min(16, max(8, proxy.size.height * 0.018))
                VStack(spacing: sectionSpacing) {
                    DPadView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    HStack(spacing: 10) {
                        RemoteButton(.home, systemImage: "house.fill", action: send)
                        RemoteButton(.back, systemImage: "arrow.uturn.backward", action: send)
                        keyboardButton
                        RemoteButton(.menu, systemImage: "gearshape.fill", action: send)
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.command) { action in
                            portalButton(action)
                        }
                    }
                    .disabled(!appState.isSelectedDevicePaired)
                    MediaControlsView(action: send)
                        .disabled(!appState.isSelectedDevicePaired)
                    appShortcutGrid
                    statusMessage
                }
                .padding(.horizontal, 16)
                .padding(.vertical, min(10, sectionSpacing))
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("STB Mode")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                errorDismissTask?.cancel()
                commandError = nil
            }
            .sheet(isPresented: $isKeyboardPresented) {
                STBKeyboardSheet { text in
                    send(.text(text))
                }
            }
            .sheet(isPresented: $isAddingShortcut) {
                AppShortcutPicker(
                    title: "Add Shortcut",
                    catalogItems: appState.availableAppCatalogItems()
                ) { shortcut in
                    _ = appState.addAppShortcut(shortcut)
                }
            }
            .sheet(item: $shortcutBeingEdited) { shortcut in
                AppShortcutPicker(
                    title: "Replace Shortcut",
                    currentShortcut: shortcut,
                    catalogItems: appState.availableAppCatalogItems(replacing: shortcut.id)
                ) { replacement in
                    _ = appState.updateAppShortcut(replacement)
                }
            }
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if !appState.isSelectedDevicePaired {
            statusLabel(
                "Pair this TV from Devices to enable STB controls.",
                systemImage: "lock.fill",
                color: .orange
            )
        } else if let commandError {
            statusLabel(
                commandError,
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
            .accessibilityLabel("Remote error: \(commandError)")
        }
    }

    private func statusLabel(
        _ message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(color)
            .lineLimit(2)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var appShortcutGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                ForEach(Array(appState.appShortcuts.enumerated()), id: \.element.id) { index, shortcut in
                    appShortcutButton(shortcut, at: index)
                }
                if appState.canAddAppShortcut {
                    Button { isAddingShortcut = true } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(.indigo)
                            .background(
                                Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                    }
                    .buttonStyle(RemotePressedButtonStyle(prominence: false))
                    .accessibilityLabel("Add app shortcut")
                }
            }
        }
    }

    private func appShortcutButton(
        _ shortcut: RemoteAppShortcut,
        at index: Int
    ) -> some View {
        Button { send(.launchApp(shortcut.launchIdentifier)) } label: {
            VStack(spacing: 5) {
                shortcutIcon(shortcut.icon)
                    .font(.headline.weight(.bold))
                Text(shortcut.displayName)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .foregroundStyle(Color.primary)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: false))
        .disabled(!appState.isSelectedDevicePaired)
        .accessibilityLabel("Open \(shortcut.displayName)")
        .accessibilityAction(named: "Edit") { shortcutBeingEdited = shortcut }
        .accessibilityAction(named: "Remove") {
            appState.removeAppShortcut(id: shortcut.id)
        }
        .contextMenu {
            Button("Edit", systemImage: "pencil") { shortcutBeingEdited = shortcut }
            Button("Move Earlier", systemImage: "arrow.left") {
                appState.moveAppShortcut(id: shortcut.id, by: -1)
            }
            .disabled(index == 0)
            Button("Move Later", systemImage: "arrow.right") {
                appState.moveAppShortcut(id: shortcut.id, by: 1)
            }
            .disabled(index == appState.appShortcuts.count - 1)
            Divider()
            Button("Remove", systemImage: "trash", role: .destructive) {
                appState.removeAppShortcut(id: shortcut.id)
            }
        }
    }

    @ViewBuilder
    private func shortcutIcon(_ icon: RemoteAppShortcut.Icon) -> some View {
        switch icon {
        case .initials(let value):
            Text(value)
                .frame(width: 28, height: 28)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(.white)
        case .system(let name):
            Image(systemName: name)
                .frame(width: 28, height: 28)
                .foregroundStyle(.indigo)
        }
    }

    private var keyboardButton: some View {
        Button { isKeyboardPresented = true } label: {
            Image(systemName: "keyboard")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(Color.primary)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16)
                )
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: false))
        .accessibilityLabel("Open keyboard")
    }

    private func portalButton(
        _ action: (command: RemoteCommand, title: String, color: Color)
    ) -> some View {
        Button { send(action.command) } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(action.color)
                    .frame(width: 11, height: 11)
                Text(action.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(Color.primary)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(RemotePressedButtonStyle(prominence: false))
        .accessibilityLabel(action.command.accessibilityLabel)
    }

    private func send(_ command: RemoteCommand) {
        Task {
            let message = await appState.send(command)
            guard isVisible else { return }
            showTransientError(message)
        }
    }

    private func showTransientError(_ message: String?) {
        errorDismissTask?.cancel()
        withAnimation { commandError = message }
        guard let message else { return }
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, commandError == message else { return }
            withAnimation { commandError = nil }
        }
    }
}

private struct AppShortcutPicker: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let currentShortcut: RemoteAppShortcut?
    let catalogItems: [RemoteAppCatalogItem]
    let onSave: (RemoteAppShortcut) -> Void

    init(
        title: String,
        currentShortcut: RemoteAppShortcut? = nil,
        catalogItems: [RemoteAppCatalogItem],
        onSave: @escaping (RemoteAppShortcut) -> Void
    ) {
        self.title = title
        self.currentShortcut = currentShortcut
        self.catalogItems = catalogItems
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Popular Apps") {
                    ForEach(catalogItems) { item in
                        Button {
                            let shortcut = item.makeShortcut(
                                id: currentShortcut?.id ?? UUID()
                            )
                            onSave(shortcut)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                catalogIcon(item.icon)
                                Text(item.displayName)
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.indigo)
                            }
                        }
                        .accessibilityLabel("Use \(item.displayName)")
                    }
                }
                Section {
                    NavigationLink {
                        AppShortcutEditor(shortcut: currentShortcut) { shortcut in
                            onSave(shortcut)
                            dismiss()
                        }
                    } label: {
                        Label("Advanced / Custom Shortcut", systemImage: "wrench.and.screwdriver")
                    }
                } footer: {
                    Text("Custom shortcuts require a Remote v2 launch identifier supported by your TV.")
                        .font(.footnote)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func catalogIcon(_ icon: RemoteAppShortcut.Icon) -> some View {
        switch icon {
        case .initials(let value):
            Text(value)
                .font(.subheadline.weight(.bold))
                .frame(width: 32, height: 32)
                .background(Color.indigo, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        case .system(let name):
            Image(systemName: name)
                .frame(width: 32, height: 32)
                .foregroundStyle(.indigo)
        }
    }
}

private struct AppShortcutEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: RemoteAppShortcut
    @State private var usesInitials: Bool
    let onSave: (RemoteAppShortcut) -> Void

    init(
        shortcut: RemoteAppShortcut? = nil,
        onSave: @escaping (RemoteAppShortcut) -> Void
    ) {
        let shortcut = shortcut ?? RemoteAppShortcut(
            displayName: "",
            launchIdentifier: "",
            icon: .system("app.fill")
        )
        self.onSave = onSave
        _shortcut = State(initialValue: shortcut)
        _usesInitials = State(initialValue: {
            if case .initials = shortcut.icon { return true }
            return false
        }())
    }

    private var isValid: Bool {
        !shortcut.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !shortcut.launchIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("App") {
                TextField("Display name", text: $shortcut.displayName)
                TextField("Launch identifier", text: $shortcut.launchIdentifier, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section("Icon") {
                Picker("Icon style", selection: $usesInitials) {
                    Text("Generic").tag(false)
                    Text("Initial").tag(true)
                }
                .pickerStyle(.segmented)
            }
        }
        .navigationTitle("Advanced Shortcut")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!isValid)
            }
        }
    }

    private func save() {
        let trimmedName = shortcut.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        shortcut.catalogID = nil
        shortcut.icon = usesInitials
            ? .initials(String(trimmedName.prefix(1)).uppercased())
            : .system("app.fill")
        onSave(shortcut)
        dismiss()
    }
}

private struct STBKeyboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text = ""
    let onSend: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Select a text field on your TV, then enter text here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("Enter text", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(sendText)
                Spacer()
            }
            .padding()
            .navigationTitle("Keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", action: sendText)
                        .disabled(text.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium])
    }

    private func sendText() {
        guard !text.isEmpty else { return }
        onSend(text)
        dismiss()
    }
}

#Preview("Light") { STBModeView(appState: .preview) }
#Preview("Dark") { STBModeView(appState: .preview).preferredColorScheme(.dark) }
