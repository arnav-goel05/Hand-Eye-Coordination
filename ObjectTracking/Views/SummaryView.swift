import SwiftUI
import RealityKit

struct SummaryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSummary: SummaryType?

    private enum SummaryType: Identifiable {
        case straight, zigzagBeginner, zigzagAdvanced

        var id: Int {
            switch self {
            case .straight: return 0
            case .zigzagBeginner: return 1
            case .zigzagAdvanced: return 2
            }
        }
    }
    
    private func headsetPos(for type: SummaryType) -> SIMD3<Float>? {
        switch type {
        case .straight: return dataManager.straightHeadsetPosition
        case .zigzagBeginner: return dataManager.zigzagBeginnerHeadsetPosition
        case .zigzagAdvanced: return dataManager.zigzagAdvancedHeadsetPosition
        }
    }

    private func objectPos(for type: SummaryType) -> SIMD3<Float>? {
        switch type {
        case .straight: return dataManager.straightObjectPosition
        case .zigzagBeginner: return dataManager.zigzagBeginnerObjectPosition
        case .zigzagAdvanced: return dataManager.zigzagAdvancedObjectPosition
        }
    }

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

        HStack(spacing: 15) {
            Button("Straight Path") {
                selectedSummary = .straight
            }
            .buttonTextStyle()
            Button("Zigzag Beginner Path") {
                selectedSummary = .zigzagBeginner
            }
            .buttonTextStyle()
            Button("Zigzag Advanced Path") {
                selectedSummary = .zigzagAdvanced
            }
            .buttonTextStyle()
        }
        .fullScreenCover(item: $selectedSummary) { which in
            SummaryImmersiveView(
                userTrace: userTrace(for: which),
                headsetPos: headsetPos(for: which),
                objectPos: objectPos(for: which),
                lineType: {
                    switch which {
                    case .straight: return .straight
                    case .zigzagBeginner: return .zigzagBeginner
                    case .zigzagAdvanced: return .zigzagAdvanced
                    }
                }()
            )
        }
    }

    private func userTrace(for type: SummaryType) -> [SIMD3<Float>] {
        switch type {
        case .straight: return dataManager.straightUserTrace
        case .zigzagBeginner: return dataManager.zigzagBeginnerUserTrace
        case .zigzagAdvanced: return dataManager.zigzagAdvancedUserTrace
        }
    }
}
