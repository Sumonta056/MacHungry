import SwiftUI
import HungryCore

struct ControlsSection: View {
    let model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: PopoverLayout.sectionSpacing) {
            Picker(PopoverText.animation, selection: Binding(get: { model.themeID }, set: { model.selectTheme(id: $0) })) {
                ForEach(ThemeRegistry.all, id: \.id) { theme in
                    Text(theme.displayName).tag(theme.id)
                }
            }
            Picker(PopoverText.show, selection: Binding(get: { model.topAppsLimit }, set: { model.selectTopAppsLimit($0) })) {
                ForEach(TopAppsLimit.allCases, id: \.self) { limit in
                    Text("\(limit.rawValue)").tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Toggle(PopoverText.launchAtLogin, isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            if let loginError = model.loginError {
                Text(loginError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button(PopoverText.quitApp) { NSApp.terminate(nil) }
            }
        }
    }
}
