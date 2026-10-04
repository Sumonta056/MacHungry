import SwiftUI
import HungryCore

struct AppRowView: View {
    let app: AppUsage
    let icon: NSImage
    let canQuit: Bool
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: PopoverLayout.itemSpacing) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: PopoverLayout.rowIconSize, height: PopoverLayout.rowIconSize)
            Text(String(format: PopoverLayout.rowPercentFormat, app.percent))
                .monospacedDigit()
                .frame(width: PopoverLayout.rowPercentWidth, alignment: .trailing)
            Text(app.identity.name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Button(action: onQuit) {
                Image(systemName: PopoverText.quitIcon)
                    .imageScale(.small)
            }
            .buttonStyle(.borderless)
            .help(PopoverText.quitHelp(name: app.identity.name))
            .opacity(canQuit ? 1 : 0)
            .disabled(!canQuit)
        }
        .frame(height: PopoverLayout.rowHeight)
    }
}
