import SwiftUI

public struct DeviceSelectorView: View {
    @Bindable var store: AppMixerStore

    public init(store: AppMixerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                let currentOut = store.outputDevices.first { $0.id == store.selectedOutputID }
                let symbol = currentOut?.symbolName ?? "speaker.wave.2"

                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LiquidGlassTheme.accentCyan)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OUTPUT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(currentOut?.name ?? "Select Output")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    ForEach(store.outputDevices) { device in
                        Button {
                            store.selectOutputDevice(device)
                        } label: {
                            HStack {
                                Text(device.name)
                                if device.id == store.selectedOutputID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .glassCard(cornerRadius: 10, padding: 8)

            HStack(spacing: 10) {
                let currentIn = store.inputDevices.first { $0.id == store.selectedInputID }
                let symbol = currentIn?.symbolName ?? "mic.fill"

                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LiquidGlassTheme.accentBlue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("INPUT / MICROPHONE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    Text(currentIn?.name ?? "Select Input")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Menu {
                    ForEach(store.inputDevices) { device in
                        Button {
                            store.selectInputDevice(device)
                        } label: {
                            HStack {
                                Text(device.name)
                                if device.id == store.selectedInputID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .glassCard(cornerRadius: 10, padding: 8)
        }
        .padding(.horizontal, 14)
    }
}
