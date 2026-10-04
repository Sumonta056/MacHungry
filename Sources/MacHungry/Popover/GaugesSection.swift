import SwiftUI
import HungryCore

struct GaugesSection: View {
    let store: StatsStore

    var body: some View {
        UsageGaugeRow(label: PopoverText.cpu, percent: store.cpuPercent, detail: nil)
        UsageGaugeRow(
            label: PopoverText.ram,
            percent: store.memory?.percent,
            detail: store.memory.map { UsageFormatter.memoryDetail(usedBytes: $0.usedBytes, totalBytes: $0.totalBytes) }
        )
        if let temperature = store.temperature {
            TemperatureRow(reading: temperature)
        }
    }
}
