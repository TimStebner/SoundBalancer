import SwiftUI

public struct PopoverContentView: View {
    @Bindable var store: AppMixerStore

    public init(store: AppMixerStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 10) {
            HeaderView(store: store)

            PermissionBannerView(store: store)

            Divider()
                .background(Color.white.opacity(0.08))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    DeviceSelectorView(store: store)

                    Toggle("Skip apps using microphone", isOn: $store.skipAppsDuringInputCapture)
                        .toggleStyle(.switch)
                        .font(.system(size: 11, weight: .medium))
                        .help("Route microphone-capturing apps directly through macOS until capture ends")
                        .padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("APPLICATIONS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(store.processMonitor.apps.count) active")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)

                        if store.processMonitor.apps.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "speaker.slash")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("No audio playing")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("Start playing audio in WhatsApp, YouTube, Spotify, or any app to adjust its volume.")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .glassCard(cornerRadius: 12, padding: 12)
                            .padding(.horizontal, 14)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(store.processMonitor.apps) { app in
                                    AppVolumeRowView(store: store, app: app)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 350)
        .frame(minHeight: 380, maxHeight: 520)
        .background(
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.75)
                Rectangle().fill(.ultraThinMaterial)
            }
        )
    }
}
