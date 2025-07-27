import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(spacing: 50) {
            Text("Overall Summary")
                .titleTextStyle()
            Text("Total finger tracking distance: \(String(format: "%.3f", dataManager.totalTraceLength)) m")
                .subtitleTextStyle()
            Text("Maximum amplitude from center line: \(String(format: "%.3f", dataManager.maxAmplitude)) m")
                .subtitleTextStyle()
            Text("Average amplitude from center line: \(String(format: "%.3f", dataManager.averageAmplitude)) m")
                .subtitleTextStyle()
        }
    }
}
