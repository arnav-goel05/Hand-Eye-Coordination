import SwiftUI
import RealityKit

enum SummaryLineType {
    case straight
    case zigzagBeginner
    case zigzagAdvanced
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

struct SummaryImmersiveView: View {
    let userTrace: [SIMD3<Float>]
    let headsetPos: SIMD3<Float>?
    let objectPos: SIMD3<Float>?
    let lineType: SummaryLineType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RealityView { content in
                let root = Entity()
                let sphereMesh = await MeshResource.generateSphere(radius: 0.0020)
                
                if let headsetPos = headsetPos, let objectPos = objectPos {
                    let shiftFraction: Float = 0.5
                    let shiftedObjectPos = objectPos + (headsetPos - objectPos) * shiftFraction

                    let headsetDot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                    headsetDot.position = headsetPos - objectPos
                    root.addChild(headsetDot)

                    let objectDot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                    objectDot.position = .zero
                    root.addChild(objectDot)
                    
                    // Draw guidance dots based on lineType
                    switch lineType {
                    case .straight:
                        let guideDots = generateStraightLineGuideDots(start: shiftedObjectPos, end: headsetPos)
                        let center = guideDots.reduce(.zero, +) / Float(guideDots.count)
                        for pt in guideDots {
                            let dot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                            dot.position = pt - center
                            root.addChild(dot)
                        }
                        // Draw user finger trace path (if available)
                        if !userTrace.isEmpty {
                            // Center the trace points around their average
                            let traceCenter = userTrace.reduce(.zero, +) / Float(userTrace.count)
                            for pt in userTrace {
                                let traceDot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
                                traceDot.position = pt - traceCenter
                                root.addChild(traceDot)
                            }
                        }
                    case .zigzagBeginner:
                        let amplitude: Float = 0.05 // beginner
                        let frequency = 4
                        let guideDots = generateZigZagGuideDots(start: shiftedObjectPos, end: headsetPos, amplitude: amplitude, frequency: frequency)
                        let center = guideDots.reduce(.zero, +) / Float(guideDots.count)
                        for pt in guideDots {
                            let dot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                            dot.position = pt - center
                            root.addChild(dot)
                        }
                        // Draw user finger trace path (if available)
                        if !userTrace.isEmpty {
                            // Center the trace points around their average
                            let traceCenter = userTrace.reduce(.zero, +) / Float(userTrace.count)
                            for pt in userTrace {
                                let traceDot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
                                traceDot.position = pt - traceCenter
                                root.addChild(traceDot)
                            }
                        }
                    case .zigzagAdvanced:
                        let amplitude: Float = 0.05 // advanced
                        let frequency = 8
                        let guideDots = generateZigZagGuideDots(start: shiftedObjectPos, end: headsetPos, amplitude: amplitude, frequency: frequency)
                        let center = guideDots.reduce(.zero, +) / Float(guideDots.count)
                        for pt in guideDots {
                            let dot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
                            dot.position = pt - center
                            root.addChild(dot)
                        }
                        // Draw user finger trace path (if available)
                        if !userTrace.isEmpty {
                            // Center the trace points around their average
                            let traceCenter = userTrace.reduce(.zero, +) / Float(userTrace.count)
                            for pt in userTrace {
                                let traceDot = ModelEntity(mesh: sphereMesh, materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
                                traceDot.position = pt - traceCenter
                                root.addChild(traceDot)
                            }
                        }
                    }
                    
                }
                
                content.add(root)
            }
            .ignoresSafeArea()
            Button("Close") {
                dismiss()
            }
            .padding()
            .background(.thinMaterial)
            .cornerRadius(12)
            .padding([.top, .trailing], 32)
        }
    }
}

