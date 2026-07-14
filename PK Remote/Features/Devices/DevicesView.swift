import SwiftUI

struct DevicesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Google TV") {
                    HStack(spacing: 14) {
                        Image(systemName: "tv.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                            .frame(width: 44, height: 44)
                            .background(.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading) {
                            Text("PKD").font(.headline)
                            Text("Placeholder device").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "circle.fill").font(.caption).foregroundStyle(.green)
                            .accessibilityLabel("Available")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("PKD, Google TV, placeholder device, available")
                }
            }
            .navigationTitle("Devices")
        }
    }
}

#Preview { DevicesView() }
