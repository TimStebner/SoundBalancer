import SwiftUI

public struct HeaderView: View {
    @Bindable var store: AppMixerStore

    public init(store: AppMixerStore) {
        self.store = store
    }

    public var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [LiquidGlassTheme.accentCyan, LiquidGlassTheme.accentBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: LiquidGlassTheme.accentCyan.opacity(0.4), radius: 6, x: 0, y: 0)

                    Image(systemName: "waveform.badge.magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("SoundBalancer")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(store.isMasterEnabled ? "Active" : "Bypassed")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(store.isMasterEnabled ? .green : .secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $store.isMasterEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.75)
                .help(store.isMasterEnabled ? "Disable SoundBalancer (Bypass)" : "Enable SoundBalancer")

            Button {
                store.teardown()
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Quit SoundBalancer (Clean exit, releases all audio taps)")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}
