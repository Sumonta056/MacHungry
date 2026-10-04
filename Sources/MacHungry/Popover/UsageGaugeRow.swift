import SwiftUI
import HungryCore

struct UsageGaugeRow: View {
    let label: String
    let percent: Double?
    let detail: String?

    var body: some View {
        HStack(spacing: PopoverLayout.itemSpacing) {
            Text(label)
                .font(.callout.weight(.semibold))
                .frame(width: PopoverLayout.gaugeLabelWidth, alignment: .leading)
            Text(UsageFormatter.percent(percent))
                .monospacedDigit()
                .frame(width: PopoverLayout.gaugeValueWidth, alignment: .trailing)
            ProgressView(value: min(max(percent ?? 0, 0), PopoverLayout.gaugeMaximum), total: PopoverLayout.gaugeMaximum)
                .frame(width: PopoverLayout.gaugeBarWidth)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
