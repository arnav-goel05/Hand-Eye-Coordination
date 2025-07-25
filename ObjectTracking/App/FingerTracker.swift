// FingerTracker.swift
// I3D-stroke-rehab
//
// Handles finger movement tracking and continuous line visualization.

import ARKit
import RealityKit
import SwiftUI
import simd

@MainActor
class FingerTracker {

    private let lineWidth: Float = 0.005       // Width of the continuous line
    private let minTraceDistance: Float = 0    // Min distance to add a new point
    private let touchMargin: Float = 0.02      // 2 cm margin around box

    private let halfExtents: SIMD3<Float>      // Half the size of the object’s bounding box

    private(set) var isTracing: Bool = false
    private var traceSegments: [[SIMD3<Float>]] = []
    private var traceLineEntities: [ModelEntity] = []

    private let traceContainer: Entity

    init(parentEntity: Entity, objectExtents: SIMD3<Float>) {
        self.halfExtents = objectExtents / 2

        let container = Entity()
        container.name = "finger trace line"
        parentEntity.addChild(container)
        self.traceContainer = container
    }

    func startTracing() {
        guard !isTracing else { return }
        isTracing = true
        traceSegments.append([])
        traceLineEntities.append(ModelEntity()) // Placeholder; will be replaced when drawing
        print("Started finger tracing")
    }

    func stopTracing() {
        guard isTracing else { return }
        isTracing = false
        print("Stopped finger tracing.")
    }

    func clearTrace() {
        for entity in traceLineEntities { entity.removeFromParent() }
        traceSegments.removeAll()
        traceLineEntities.removeAll()
        print("Cleared all finger traces")
    }

    func updateFingerTrace(fingerWorldPos: SIMD3<Float>, relativeTo entity: Entity) {
        guard isTracing, !traceSegments.isEmpty else { return }
        var currentSegment = traceSegments.removeLast()
        if let last = currentSegment.last {
            let d = simd_length(fingerWorldPos - last)
            if d < minTraceDistance {
                traceSegments.append(currentSegment)
                return
            }
        }
        currentSegment.append(fingerWorldPos)
        traceSegments.append(currentSegment)
        updateTraceVisualization(relativeTo: entity)
    }

    private func updateTraceVisualization(relativeTo entity: Entity) {
        guard let segmentIndex = traceSegments.indices.last else { return }
        let pts = traceSegments[segmentIndex]
        guard pts.count >= 2 else { return }
        let localPts = pts.map { entity.convert(position: $0, from: nil) }
        let mesh = createTubeMesh(from: localPts, radius: lineWidth/2, radialSegments: 16)
        let yellowMaterial = UnlitMaterial(color: UIColor(red: 1, green: 1, blue: 0, alpha: 1))
        // Remove old entity if exists
        if traceLineEntities[segmentIndex].parent != nil {
            traceLineEntities[segmentIndex].removeFromParent()
        }
        let newEntity = ModelEntity(mesh: mesh, materials: [yellowMaterial])
        traceContainer.addChild(newEntity)
        traceLineEntities[segmentIndex] = newEntity
    }

    private func createTubeMesh(from pts: [SIMD3<Float>], radius: Float, radialSegments: Int = 12) -> MeshResource {
        guard pts.count >= 2 else {
            return MeshResource.generateSphere(radius: radius) // fallback for single point
        }
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for i in 0..<pts.count {
            let dir: SIMD3<Float>
            if i == 0 {
                dir = normalize(pts[1] - pts[0])
            } else if i == pts.count - 1 {
                dir = normalize(pts[i] - pts[i-1])
            } else {
                dir = normalize(pts[i+1] - pts[i-1])
            }
            let up = abs(dir.y) < 0.99 ? SIMD3<Float>(0,1,0) : SIMD3<Float>(1,0,0)
            let right = normalize(cross(dir, up))
            let actualUp = normalize(cross(right, dir))

            for j in 0..<radialSegments {
                let theta = 2 * Float.pi * Float(j) / Float(radialSegments)
                let offset = cos(theta) * right * radius + sin(theta) * actualUp * radius
                vertices.append(pts[i] + offset)
                normals.append(normalize(offset))
            }
        }
        let rings = pts.count
        for i in 0..<rings-1 {
            for j in 0..<radialSegments {
                let current = UInt32(i * radialSegments + j)
                let next = UInt32((i+1) * radialSegments + j)
                let currentNext = UInt32(i * radialSegments + (j+1)%radialSegments)
                let nextNext = UInt32((i+1)*radialSegments + (j+1)%radialSegments)
                indices += [current, next, currentNext]
                indices += [currentNext, next, nextNext]
            }
        }
        var desc = MeshDescriptor(name: "TubeLine")
        desc.positions = MeshBuffer(vertices)
        desc.normals = MeshBuffer(normals)
        desc.primitives = .triangles(indices)
        return try! MeshResource.generate(from: [desc])
    }

    func getTracePoints() -> [SIMD3<Float>] {
        return traceSegments.flatMap { $0 }
    }

    func getTraceLength() -> Float {
        return traceSegments.reduce(0) { sum, segment in
            guard segment.count > 1 else { return sum }
            return sum + zip(segment, segment.dropFirst()).reduce(0) { $0 + simd_length($1.1 - $1.0) }
        }
    }
}
