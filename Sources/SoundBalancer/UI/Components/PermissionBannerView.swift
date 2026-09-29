import SwiftUI

public struct PermissionBannerView: View {
    @Bindable var store: AppMixerStore

    public init(store: AppMixerStore) {
        self.store = store
    }

    public var body: some View {
        if !store.permission.isAuthorized {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))

                    Text("Audio Capture Permission Needed")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Button {
                        store.permission.request {
                            Task { @MainActor in
                                store.reconcile()
                            }
                        }
                    } label: {
                        Text("Grant Access")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(LiquidGlassTheme.accentBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("macOS requires permission to route and balance audio between applications.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .glassCard(cornerRadius: 10, padding: 10)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
    }
}
