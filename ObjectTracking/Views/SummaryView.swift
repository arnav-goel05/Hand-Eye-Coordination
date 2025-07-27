import SwiftUI

struct SummaryView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Summary from both sets of activities")
                .font(.largeTitle)
            Text("Total finger tracking distance: \(String(format: "%.3f", dataManager.totalTraceLength)) m")
            Text("Maximum amplitude from center line: \(String(format: "%.3f", dataManager.maxAmplitude)) m")
            Text("Average amplitude from center line: \(String(format: "%.3f", dataManager.averageAmplitude)) m")
        }
        .padding()
    }
}
