import SwiftUI

public struct EqualizerView: View {
    @Bindable var store: AppMixerStore

    public init(store: AppMixerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("EQUALIZER")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Spacer()

                Menu {
                    ForEach(EQPreset.builtIns) { preset in
                        Button {
                            store.applyPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.name)
                                if store.selectedPresetName == preset.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(store.selectedPresetName)
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $store.isEQEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.7)
            }
            .padding(.horizontal, 14)

            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    GlassVerticalEQSlider(
                        gainDB: Binding(
                            get: { store.eqGains[index] },
                            set: { store.setEQGain(bandIndex: index, gainDB: $0) }
                        ),
                        label: EQPreset.standardFrequencyLabels[index]
                    )
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .glassCard(cornerRadius: 12, padding: 8)
            .opacity(store.isEQEnabled ? 1.0 : 0.45)
            .disabled(!store.isEQEnabled)
            .padding(.horizontal, 10)

            HStack {
                Button {
                    store.resetEQ()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset EQ")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 14)
        }
    }
}
