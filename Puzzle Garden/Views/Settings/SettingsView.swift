import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    private let warmGreen = Color(red: 0.353, green: 0.478, blue: 0.235)
    private let bg = Color(red: 0.961, green: 0.941, blue: 0.910)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            List {
                Section {
                    Toggle(isOn: $soundEnabled) {
                        Label("Sound", systemImage: "speaker.wave.2.fill")
                            .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                    }
                    .tint(warmGreen)

                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "hand.tap.fill")
                            .foregroundStyle(Color(red: 0.30, green: 0.22, blue: 0.14))
                    }
                    .tint(warmGreen)
                } header: {
                    Text("Feedback")
                        .font(.system(.footnote, design: .rounded))
                }
                .listRowBackground(Color(red: 0.98, green: 0.97, blue: 0.95))

                Section {
                    HStack {
                        Text("Version")
                            .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.25))
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(Color(red: 0.60, green: 0.50, blue: 0.40))
                    }
                }
                .listRowBackground(Color(red: 0.98, green: 0.97, blue: 0.95))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .font(.system(.body, design: .rounded))
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
