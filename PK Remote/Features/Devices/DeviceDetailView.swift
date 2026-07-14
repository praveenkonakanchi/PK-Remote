import SwiftUI

struct DeviceDetailView: View {
    let device: RemoteDevice
    let appState: AppState

    @State private var pairingCode = ""

    private var pairingState: DevicePairingState {
        appState.pairingState(for: device)
    }

    var body: some View {
        Form {
            Section("Device") {
                LabeledContent("Name", value: device.name)
                LabeledContent("Type", value: device.kind)
                LabeledContent("Status", value: device.availability.rawValue)
            }

            Section("Pairing") {
                pairingContent
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { appState.select(device) }
    }

    @ViewBuilder
    private var pairingContent: some View {
        switch pairingState {
        case .unpaired:
            Button("Pair Device") {
                Task { await appState.requestPairingCode(for: device) }
            }

        case .requestingCode:
            HStack {
                ProgressView()
                Text("Requesting a code from the TV…")
            }

        case .awaitingCode:
            Text("Enter the 6-digit code shown on your TV.")
                .foregroundStyle(.secondary)
            TextField("Pairing code", text: $pairingCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .onChange(of: pairingCode) { _, value in
                    pairingCode = String(value.filter(\.isNumber).prefix(6))
                }
                .accessibilityLabel("6-digit pairing code")
            Button("Pair") {
                Task { await appState.submitPairingCode(pairingCode, for: device) }
            }
            .disabled(pairingCode.count != 6)
            Button("Cancel", role: .cancel) {
                Task { await appState.cancelPairing(for: device) }
            }

        case .pairing:
            HStack {
                ProgressView()
                Text("Pairing…")
            }

        case .paired:
            Label("Paired", systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Button("Try Again") {
                pairingCode = ""
                Task { await appState.requestPairingCode(for: device) }
            }
            Button("Cancel", role: .cancel) {
                Task { await appState.cancelPairing(for: device) }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DeviceDetailView(device: .placeholder, appState: .preview)
    }
}
