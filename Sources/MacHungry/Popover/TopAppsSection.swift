import SwiftUI
import HungryCore

struct TopAppsSection: View {
    let store: StatsStore
    let iconCache: IconCache
    let quitCache: QuitCache
    let limit: TopAppsLimit

    var body: some View {
        HStack {
            Text(PopoverText.topAppsHeading(limit: limit.rawValue)).font(.callout.weight(.semibold))
            Spacer()
            if store.isLimited {
                Text(PopoverText.limited)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help(PopoverText.limitedHelp)
            }
        }
        if !store.hasTopSample {
            Text(PopoverText.measuring).foregroundStyle(.secondary)
        } else if store.topApps.isEmpty {
            Text(PopoverText.noActivity).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.topApps) { app in
                    AppRowView(
                        app: app,
                        icon: iconCache.icon(for: app),
                        canQuit: quitCache.canQuit(app),
                        onQuit: { AppTerminator.confirmAndQuit(app) }
                    )
                }
            }
        }
    }
}
