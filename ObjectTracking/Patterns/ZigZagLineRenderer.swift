// ZigZagLineRenderer.swift
// I3D-stroke-rehab
//
// Abstract:
// Renders a zig-zag dotted red line from the headset to the target object, similar in structure to HeadsetLineRenderer.

import ARKit
import RealityKit
import simd
import UIKit

@MainActor
class ZigZagLineRenderer {

    private let dotRadius: Float = 0.0015
    private let dotSpacing: Float = 0.001
    private let maxDots: Int = 1000
    private var isFrozen: Bool = false // When true, skip updates
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []

    init(parentEntity: Entity) {
        let container = Entity()
        container.name = "device→object zigzag dots"
        parentEntity.addChild(container)
        self.lineContainer = container
        createDotPool()
    }

    func freezeDots() {
        isFrozen = true
    }

    private func createDotPool() {
        let sphereMesh = MeshResource.generateSphere(radius: dotRadius)
        let sphereMaterial = SimpleMaterial(
            color: .init(red: 1, green: 1, blue: 1, alpha: 1),
            isMetallic: false
        )

        for _ in 0..<maxDots {
            let dot = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            dot.isEnabled = false
            lineContainer.addChild(dot)
            dotEntities.append(dot)
        }
    }

    private func computeZigZagPoints(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        count dotCount: Int,
        amplitude: Float,
        frequency: Int
    ) -> [SIMD3<Float>] {
        guard dotCount > 0 else { return [start, end] }
        let direction = normalize(end - start)
        let totalLength = simd_length(end - start)

        let up: SIMD3<Float> = abs(direction.y) < 0.99 ? [0, 1, 0] : [1, 0, 0]
        let right = normalize(cross(direction, up))

        var points: [SIMD3<Float>] = []
        for i in 0...dotCount {
            let t = Float(i) / Float(dotCount)
            let point = start + direction * (totalLength * t)

            let phase = Float(i) * Float(frequency) * .pi / Float(dotCount)
            let amp = (i == 0 || i == dotCount) ? 0 : amplitude * sin(phase)
            let offset = right * amp

            points.append(point + offset)
        }

        return points
    }

    func updateZigZagLine(
        from headsetPos: SIMD3<Float>,
        to objectPos: SIMD3<Float>,
        relativeTo entity: Entity,
        amplitude: Float,
        frequency: Int
    ) {
        guard !isFrozen else { return }

        lineContainer.isEnabled = true

        let lineVector = objectPos - headsetPos
        let lineLength = simd_length(lineVector)
        let computedDotCount = Int(lineLength / dotSpacing)
        let dotCount = min(maxDots - 1, computedDotCount)

        let zigZagPoints = computeZigZagPoints(from: headsetPos, to: objectPos, count: dotCount, amplitude: amplitude, frequency: frequency)

        for i in 0..<maxDots {
            let dot = dotEntities[i]
            if i < zigZagPoints.count {
                let worldPosition = zigZagPoints[i]
                let localPosition = entity.convert(position: worldPosition, from: nil)
                dot.transform.translation = localPosition
                dot.isEnabled = true
                if i == 0 || i == zigZagPoints.count - 1 {
                    let blackMaterial = SimpleMaterial(color: .black, isMetallic: false)
                    if let mesh = dot.model?.mesh, mesh.bounds.extents.x != 0.003 * 2 {
                        dot.model?.mesh = MeshResource.generateSphere(radius: 0.003)
                    }
                    if let mat = dot.model?.materials.first as? SimpleMaterial {
                        if let matColor = mat.color as? UIColor {
                            if matColor != UIColor.black {
                                dot.model?.materials = [blackMaterial]
                            }
                        } else {
                            dot.model?.materials = [blackMaterial]
                        }
                    } else {
                        dot.model?.materials = [blackMaterial]
                    }
                } else {
                    let whiteMaterial = SimpleMaterial(color: .white, isMetallic: false)
                    if let mesh = dot.model?.mesh, mesh.bounds.extents.x != dotRadius * 2 {
                        dot.model?.mesh = MeshResource.generateSphere(radius: dotRadius)
                    }
                    if let mat = dot.model?.materials.first as? SimpleMaterial {
                        if let matColor = mat.color as? UIColor {
                            if matColor != UIColor.white {
                                dot.model?.materials = [whiteMaterial]
                            }
                        } else {
                            dot.model?.materials = [whiteMaterial]
                        }
                    } else {
                        dot.model?.materials = [whiteMaterial]
                    }
                }
            } else {
                dot.isEnabled = false
            }
        }
    }
    
    func hideAllDots() {
        dotEntities.forEach { $0.isEnabled = false }
        lineContainer.isEnabled = false
    }

    func showAllDots() {
        lineContainer.isEnabled = true
    }

    func updateDotAppearance(
        radius: Float? = nil,
        color: UIColor? = nil,
        alpha: Float? = nil
    ) {
        let newRadius = radius ?? dotRadius
        let newAlpha = alpha ?? 1

        let shouldUpdateMesh = radius != nil
        let shouldUpdateMaterial = color != nil || alpha != nil

        if shouldUpdateMesh || shouldUpdateMaterial {
            let mesh = shouldUpdateMesh
                ? MeshResource.generateSphere(radius: newRadius)
                : nil

            let material = shouldUpdateMaterial
                ? SimpleMaterial(
                    color: color ?? UIColor(white: 1, alpha: CGFloat(newAlpha)),
                    isMetallic: false
                )
                : nil

            for dot in dotEntities {
                if let m = mesh {
                    dot.model?.mesh = m
                }
                if let mat = material {
                    dot.model?.materials = [mat]
                }
            }
        }
    }

    func getVisibleDotCount() -> Int {
        dotEntities.filter { $0.isEnabled }.count
    }

    func getDotSpacing() -> Float {
        dotSpacing
    }

    func getMaxDotCount() -> Int {
        maxDots
    }

    func getMaxLineLength() -> Float {
        Float(maxDots) * dotSpacing
    }
    
    /// Returns the world position of the first dot (index 0) if it is enabled.
    func getFirstDotWorldPosition(relativeTo entity: Entity) -> SIMD3<Float>? {
        guard let dot = dotEntities.first, dot.isEnabled else { return nil }
        // Convert the dot's local position to world position
        let localPos = dot.transform.translation
        return entity.convert(position: localPos, to: nil)
    }
    
    /// Returns the world position of the last enabled dot in the dotEntities array.
    func getLastDotWorldPosition(relativeTo entity: Entity) -> SIMD3<Float>? {
        guard let dot = dotEntities.last(where: { $0.isEnabled }) else { return nil }
        let localPos = dot.transform.translation
        return entity.convert(position: localPos, to: nil)
    }
}
