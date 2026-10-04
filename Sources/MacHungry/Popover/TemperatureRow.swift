import SwiftUI
import HungryCore

struct TemperatureRow: View {
    let reading: TemperatureReading

    var body: some View {
        HStack(spacing: PopoverLayout.itemSpacing) {
            Text(PopoverText.temperature)
                .font(.callout.weight(.semibold))
                .frame(width: PopoverLayout.gaugeLabelWidth, alignment: .leading)
            Text(UsageFormatter.temperatureDetail(reading))
                .monospacedDigit()
        }
    }
}
