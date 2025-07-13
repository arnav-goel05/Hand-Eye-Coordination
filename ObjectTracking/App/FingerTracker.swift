// FingerTracker.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Handles finger movement tracking and continuous line visualization.

import ARKit
import RealityKit
import SwiftUI
import simd

@MainActor
class FingerTracker {
    // MARK: - Configuration
    private let lineWidth: Float = 0.005 // Width of the continuous line
    private let minTraceDistance: Float = 0 // Minimum distance to add new point
    
    // MARK: - State
    private(set) var isTracing: Bool = false
    private var tracePoints: [SIMD3<Float>] = []
    
    // MARK: - Entities
    private let traceContainer: Entity
    private var traceLineEntity: ModelEntity?
    
    init(parentEntity: Entity) {
        // Create finger trace container for continuous line
        let container = Entity()
        container.name = "finger trace line"
        parentEntity.addChild(container)
        self.traceContainer = container
    }
    
    // MARK: - Tracing Control
    
    /// Start tracing the finger's movement
    func startTracing() {
        isTracing = true
        clearTrace()
        print("Started finger tracing")
    }
    
    /// Stop tracing the finger's movement
    func stopTracing() {
        isTracing = false
        print("Stopped finger tracing")
    }
    
    /// Clear the current trace
    func clearTrace() {
        tracePoints.removeAll()
        if let lineEntity = traceLineEntity {
            traceContainer.removeChild(lineEntity)
            traceLineEntity = nil
        }
        print("Cleared finger trace")
    }
    
    // MARK: - Trace Update
    
    /// Update finger trace with new position
    func updateFingerTrace(fingerWorldPos: SIMD3<Float>, relativeTo entity: Entity) {
        guard isTracing else { return }
        
        // Check if we should add a new point (minimum distance threshold)
        if let lastPoint = tracePoints.last {
            let distance = simd_length(fingerWorldPos - lastPoint)
            if distance < minTraceDistance {
                return // Too close to last point, skip
            }
        }
        
        // Add new trace point
        tracePoints.append(fingerWorldPos)
        
        // Update visual representation
        updateTraceVisualization(relativeTo: entity)
    }
    
    // MARK: - Visualization
    
    /// Update the visual representation of the trace as a continuous line
    private func updateTraceVisualization(relativeTo entity: Entity) {
        guard tracePoints.count >= 2 else {
            // Remove line if not enough points
            if let lineEntity = traceLineEntity {
                traceContainer.removeChild(lineEntity)
                traceLineEntity = nil
            }
            return
        }
        
        // Convert world positions to local positions relative to the entity
        let localPoints = tracePoints.map { worldPos in
            entity.convert(position: worldPos, from: nil)
        }
        
        // Create line mesh from points
        let lineMesh = createLineMesh(from: localPoints, width: lineWidth)
        
        // Create or update line entity
        if let existingLineEntity = traceLineEntity {
            existingLineEntity.model?.mesh = lineMesh
        } else {
            let lineMaterial = SimpleMaterial(
                color: .init(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.8),
                isMetallic: false
            )
            let lineEntity = ModelEntity(mesh: lineMesh, materials: [lineMaterial])
            traceContainer.addChild(lineEntity)
            traceLineEntity = lineEntity
        }
    }
    
    /// Create a line mesh from a series of points
    private func createLineMesh(from points: [SIMD3<Float>], width: Float) -> MeshResource {
        var vertices: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var normals: [SIMD3<Float>] = []
        
        let halfWidth = width * 0.5
        
        for i in 0..<points.count {
            let currentPoint = points[i]
            
            // Calculate direction vectors
            let forward: SIMD3<Float>
            if i == 0 {
                forward = normalize(points[i + 1] - currentPoint)
            } else if i == points.count - 1 {
                forward = normalize(currentPoint - points[i - 1])
            } else {
                forward = normalize(points[i + 1] - points[i - 1])
            }
            
            // Calculate perpendicular vector for width
            let up = SIMD3<Float>(0, 1, 0)
            let right = normalize(cross(forward, up))
            let actualUp = normalize(cross(right, forward))
            
            // Create quad vertices for this segment
            let v1 = currentPoint + right * halfWidth + actualUp * halfWidth
            let v2 = currentPoint - right * halfWidth + actualUp * halfWidth
            let v3 = currentPoint - right * halfWidth - actualUp * halfWidth
            let v4 = currentPoint + right * halfWidth - actualUp * halfWidth
            
            let baseIndex = UInt32(vertices.count)
            vertices.append(contentsOf: [v1, v2, v3, v4])
            
            // Add normals
            let normal = actualUp
            normals.append(contentsOf: [normal, normal, normal, normal])
            
            // Create triangles for the quad (if not the last point)
            if i < points.count - 1 {
                // Two triangles per quad
                indices.append(contentsOf: [
                    baseIndex, baseIndex + 1, baseIndex + 2,
                    baseIndex, baseIndex + 2, baseIndex + 3
                ])
            }
        }
        
        // Connect segments
        for i in 0..<points.count - 1 {
            let baseIndex = UInt32(i * 4)
            let nextBaseIndex = UInt32((i + 1) * 4)
            
            // Connect the segments with triangles
            indices.append(contentsOf: [
                baseIndex, nextBaseIndex, baseIndex + 1,
                nextBaseIndex, nextBaseIndex + 1, baseIndex + 1,
                baseIndex + 1, nextBaseIndex + 1, baseIndex + 2,
                nextBaseIndex + 1, nextBaseIndex + 2, baseIndex + 2,
                baseIndex + 2, nextBaseIndex + 2, baseIndex + 3,
                nextBaseIndex + 2, nextBaseIndex + 3, baseIndex + 3,
                baseIndex + 3, nextBaseIndex + 3, baseIndex,
                nextBaseIndex + 3, nextBaseIndex, baseIndex
            ])
        }
        
        var descriptor = MeshDescriptor(name: "TraceLine")
        descriptor.positions = MeshBuffer(vertices)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [descriptor])
    }
    
    // MARK: - Data Access
    
    /// Get the current trace as an array of world positions
    func getTracePoints() -> [SIMD3<Float>] {
        return tracePoints
    }
    
    /// Get the trace length in meters
    func getTraceLength() -> Float {
        guard tracePoints.count > 1 else { return 0 }
        
        var totalLength: Float = 0
        for i in 1..<tracePoints.count {
            totalLength += simd_length(tracePoints[i] - tracePoints[i-1])
        }
        return totalLength
    }
}
