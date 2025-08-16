import SwiftUI
import RealityKit
import UniformTypeIdentifiers

struct SummaryView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedSummary: SummaryType?
    @State private var isExportingCSV = false
    @State private var csvURL: URL?

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
            
            if let start = headsetPos(for: .straight), let end = objectPos(for: .straight) {
                Button("Export All Data") {
                    exportAllData()
                }
                .buttonTextStyle()
            }
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
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvURL.map { URLDocument(fileURL: $0) },
            contentType: .commaSeparatedText,
            defaultFilename: "StraightGuideDots"
        ) { result in
            csvURL = nil
        }
    }

    private func userTrace(for type: SummaryType) -> [SIMD3<Float>] {
        switch type {
        case .straight: return dataManager.straightUserTrace
        case .zigzagBeginner: return dataManager.zigzagBeginnerUserTrace
        case .zigzagAdvanced: return dataManager.zigzagAdvancedUserTrace
        }
    }

    private func exportStraightPathDots() {
        guard let start = headsetPos(for: .straight), let end = objectPos(for: .straight) else { return }
        let dots = generateStraightLineGuideDots(start: start, end: end)
        
        var csvString = "X,Y,Z\n"
        for dot in dots {
            csvString += "\(dot.x),\(dot.y),\(dot.z)\n"
        }
        
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("StraightGuideDots.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportStraightUserTrace() {
        let trace = dataManager.straightUserTrace
        guard !trace.isEmpty else { return }
        var csvString = "X,Y,Z\n"
        for point in trace {
            csvString += "\(point.x),\(point.y),\(point.z)\n"
        }
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("StraightUserTrace.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportZigzagBeginnerPathDots() {
        guard let start = headsetPos(for: .zigzagBeginner), let end = objectPos(for: .zigzagBeginner) else { return }
        let dots = generateStraightLineGuideDots(start: start, end: end)
        
        var csvString = "X,Y,Z\n"
        for dot in dots {
            csvString += "\(dot.x),\(dot.y),\(dot.z)\n"
        }
        
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("ZigzagBeginnerGuideDots.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportZigzagBeginnerUserTrace() {
        let trace = dataManager.zigzagBeginnerUserTrace
        guard !trace.isEmpty else { return }
        var csvString = "X,Y,Z\n"
        for point in trace {
            csvString += "\(point.x),\(point.y),\(point.z)\n"
        }
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("ZigzagBeginnerUserTrace.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportZigzagAdvancedPathDots() {
        guard let start = headsetPos(for: .zigzagAdvanced), let end = objectPos(for: .zigzagAdvanced) else { return }
        let dots = generateStraightLineGuideDots(start: start, end: end)
        
        var csvString = "X,Y,Z\n"
        for dot in dots {
            csvString += "\(dot.x),\(dot.y),\(dot.z)\n"
        }
        
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("ZigzagAdvancedGuideDots.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportZigzagAdvancedUserTrace() {
        let trace = dataManager.zigzagAdvancedUserTrace
        guard !trace.isEmpty else { return }
        var csvString = "X,Y,Z\n"
        for point in trace {
            csvString += "\(point.x),\(point.y),\(point.z)\n"
        }
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("ZigzagAdvancedUserTrace.csv")
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    private func exportAllData() {
        var combinedCSV = ""
        
        if let startStraight = headsetPos(for: .straight), let endStraight = objectPos(for: .straight) {
            let dots = generateStraightLineGuideDots(start: startStraight, end: endStraight)
            if !dots.isEmpty {
                combinedCSV += "Straight Guide Dots\nX,Y,Z\n"
                for dot in dots {
                    combinedCSV += "\(dot.x),\(dot.y),\(dot.z)\n"
                }
                combinedCSV += "\n"
            }
        }
        
        let straightTrace = dataManager.straightUserTrace
        if !straightTrace.isEmpty {
            combinedCSV += "Straight User Trace\nX,Y,Z\n"
            for point in straightTrace {
                combinedCSV += "\(point.x),\(point.y),\(point.z)\n"
            }
            combinedCSV += "\n"
        }
        
        if let startZigzagBeginner = headsetPos(for: .zigzagBeginner), let endZigzagBeginner = objectPos(for: .zigzagBeginner) {
            let amplitude: Float = 0.05 // beginner
            let frequency = 4
            let dots = generateZigZagGuideDots(start: startZigzagBeginner, end: endZigzagBeginner, amplitude: amplitude, frequency: frequency)
            if !dots.isEmpty {
                combinedCSV += "Zigzag Beginner Guide Dots\nX,Y,Z\n"
                for dot in dots {
                    combinedCSV += "\(dot.x),\(dot.y),\(dot.z)\n"
                }
                combinedCSV += "\n"
            }
        }
        
        let zigzagBeginnerTrace = dataManager.zigzagBeginnerUserTrace
        if !zigzagBeginnerTrace.isEmpty {
            combinedCSV += "Zigzag Beginner User Trace\nX,Y,Z\n"
            for point in zigzagBeginnerTrace {
                combinedCSV += "\(point.x),\(point.y),\(point.z)\n"
            }
            combinedCSV += "\n"
        }
        
        if let startZigzagAdvanced = headsetPos(for: .zigzagAdvanced), let endZigzagAdvanced = objectPos(for: .zigzagAdvanced) {
            let amplitude: Float = 0.05 // beginner
            let frequency = 8
            let dots = generateZigZagGuideDots(start: startZigzagAdvanced, end: endZigzagAdvanced, amplitude: amplitude, frequency: frequency)
            if !dots.isEmpty {
                combinedCSV += "Zigzag Advanced Guide Dots\nX,Y,Z\n"
                for dot in dots {
                    combinedCSV += "\(dot.x),\(dot.y),\(dot.z)\n"
                }
                combinedCSV += "\n"
            }
        }
        
        let zigzagAdvancedTrace = dataManager.zigzagAdvancedUserTrace
        if !zigzagAdvancedTrace.isEmpty {
            combinedCSV += "Zigzag Advanced User Trace\nX,Y,Z\n"
            for point in zigzagAdvancedTrace {
                combinedCSV += "\(point.x),\(point.y),\(point.z)\n"
            }
            combinedCSV += "\n"
        }
        
        guard !combinedCSV.isEmpty else { return }
        
        do {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("AllExportedData.csv")
            try combinedCSV.write(to: fileURL, atomically: true, encoding: .utf8)
            csvURL = fileURL
            isExportingCSV = true
        } catch {
            // Handle error if needed
        }
    }
    
    func generateStraightLineGuideDots(start: SIMD3<Float>, end: SIMD3<Float>) -> [SIMD3<Float>] {
        let dotSpacing: Float = 0.001
        let maxDots = 1000
        let lineVector = end - start
        let lineLength = length(lineVector)
        if lineLength == 0 {
            return [start]
        }
        let direction = normalize(lineVector)
        let numberOfSegments = min(Int(lineLength / dotSpacing), maxDots)
        var dots: [SIMD3<Float>] = []
        dots.reserveCapacity(numberOfSegments + 1)
        for i in 0...numberOfSegments {
            dots.append(start + direction * (Float(i) * dotSpacing))
        }
        if dots.last != end {
            dots.append(end)
        }
        return dots
    }
    
    func generateZigZagGuideDots(start: SIMD3<Float>, end: SIMD3<Float>, amplitude: Float, frequency: Int, dotSpacing: Float = 0.001, maxDots: Int = 1000) -> [SIMD3<Float>] {
        let lineVector = end - start
        let lineLength = simd_length(lineVector)
        let computedDotCount = Int(lineLength / dotSpacing)
        let dotCount = min(maxDots - 1, computedDotCount)
        guard dotCount > 0 else { return [start, end] }
        let direction = simd_normalize(lineVector)
        let up: SIMD3<Float> = abs(direction.y) < 0.99 ? [0, 1, 0] : [1, 0, 0]
        let right = simd_normalize(simd_cross(direction, up))
        var points: [SIMD3<Float>] = []
        for i in 0...dotCount {
            let t = Float(i) / Float(dotCount)
            let point = start + direction * (lineLength * t)
            let phase = Float(i) * Float(frequency) * .pi / Float(dotCount)
            let amp = (i == 0 || i == dotCount) ? 0 : amplitude * sin(phase)
            let offset = right * amp
            points.append(point + offset)
        }
        return points
    }
}

private struct URLDocument: FileDocument {
    let fileURL: URL

    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    init(configuration: ReadConfiguration) throws {
        throw NSError(domain: "Not supported", code: -1, userInfo: nil)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return try FileWrapper(url: fileURL, options: .immediate)
    }
}

