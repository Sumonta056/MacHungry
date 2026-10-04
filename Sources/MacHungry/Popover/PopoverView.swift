import SwiftUI
import HungryCore

struct PopoverView: View {
    let store: StatsStore
    let iconCache: IconCache
    let quitCache: QuitCache
    let model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverLayout.sectionSpacing) {
            GaugesSection(store: store)
            Divider()
            TopAppsSection(store: store, iconCache: iconCache, quitCache: quitCache, limit: model.topAppsLimit)
            Divider()
            ControlsSection(model: model)
        }
        .frame(width: PopoverLayout.width)
        .fixedSize(horizontal: false, vertical: true)
        .padding(PopoverLayout.padding)
        .font(.callout)
        .controlSize(.small)
    }
}
