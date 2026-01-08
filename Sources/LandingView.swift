import SwiftUI

struct LandingView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Welcome to Sagasu 5")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Legal Disclaimer")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("This application is provided 'as is' without any warranties, expressed or implied. The developers and distributors of Sagasu 5 are not liable for any damages or losses resulting from the use of this software. All data is provided for informational purposes only and may not be accurate or up to date. Use at your own risk.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Infomatic")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Sagasu 5 is a menu bar app for macOS that displays room, booking, and task information. Data is fetched from public sources and may be subject to change.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 16)
        }
        .frame(width: 420, height: 560)
        .background(.background)
    }
}