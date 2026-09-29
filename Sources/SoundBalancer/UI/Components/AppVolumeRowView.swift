import AppKit
import SwiftUI

public struct AppVolumeRowView: View {
    @Bindable var store: AppMixerStore
    public let app: AudioAppItem

    public init(store: AppMixerStore, app: AudioAppItem) {
        self.store = store
        self.app = app
    }

    public var body: some View {
        let isMuted = store.isMuted(for: app)
        let volume = store.volume(for: app)
        let percent = Int(round(volume * 100.0))
        let isDefault = store.isDefault(for: app)

        VStack(spacing: 6) {
            HStack(spacing: 8) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }

                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isMuted ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Text(isMuted ? "Muted" : "\(percent)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        isMuted ? .red.opacity(0.8) :
                            (percent > 100 ? LiquidGlassTheme.boostOrange : .secondary)
                    )
                    .frame(width: 48, alignment: .trailing)

                Button {
                    store.toggleMute(for: app)
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isMuted ? .red : .secondary)
                        .padding(5)
                        .background(Color.white.opacity(isMuted ? 0.15 : 0.05))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help(isMuted ? "Unmute" : "Mute")

                if !isDefault {
                    Button {
                        store.resetApp(app)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Reset to 100%")
                }
            }

            GlassVolumeSlider(
                value: Binding(
                    get: { store.volume(for: app) },
                    set: { store.setVolume($0, for: app) }
                ),
                isMuted: isMuted
            )
        }
        .glassCard(cornerRadius: 11, padding: 10)
    }
}
