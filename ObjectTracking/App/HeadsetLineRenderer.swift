// HeadsetLineRenderer.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Renders a dotted red line from the headset to the target object.

import ARKit
import RealityKit
import simd
import UIKit

@MainActor
class HeadsetLineRenderer {
    // MARK: - Configuration
    private let dotRadius: Float = 0.002
    private let dotSpacing: Float = 0.05
    private let maxDots: Int = Int(5.0 / 0.05) // Maximum line length of 5 meters
    
    // MARK: - Entities
    private let lineContainer: Entity
    private var dotEntities: [ModelEntity] = []
    
    init(parentEntity: Entity) {
        // Create container for pooled red-dot spheres
        let container = Entity()
        container.name = "device→object dots"
        parentEntity.addChild(container)
        self.lineContainer = container
        
        // Pre-pool red-dot spheres for performance
        createDotPool()
    }
    
    // MARK: - Dot Pool Management
    
    /// Create a pool of reusable dot entities for performance
    private func createDotPool() {
        let sphereMesh = MeshResource.generateSphere(radius: dotRadius)
        let sphereMaterial = SimpleMaterial(
            color: .init(red: 1, green: 0, blue: 0, alpha: 0.8),
            isMetallic: false
        )
        
        for _ in 0..<maxDots {
            let dot = ModelEntity(mesh: sphereMesh, materials: [sphereMaterial])
            dot.isEnabled = false
            lineContainer.addChild(dot)
            dotEntities.append(dot)
        }
    }
    
    // MARK: - Line Rendering
    
    /// Update the dotted line visualization from headset to object
    func updateDottedLine(
        from headsetPos: SIMD3<Float>,
        to objectPos: SIMD3<Float>,
        relativeTo entity: Entity
    ) {
        lineContainer.isEnabled = true
        
        // Calculate line vector and length
        let lineVector = objectPos - headsetPos
        let lineLength = simd_length(lineVector)
        
        // Calculate number of dots to display
        let dotCount = min(maxDots - 1, Int(lineLength / dotSpacing))
        
        // Position dots along the line
        for i in 0..<maxDots {
            let dot = dotEntities[i]
            
            if i <= dotCount {
                // Calculate position along the line
                let t = Float(i) / Float(max(dotCount, 1))
                let worldPosition = headsetPos + lineVector * t
                
                // Convert to local coordinates relative to the entity
                let localPosition = entity.convert(position: worldPosition, from: nil)
                
                // Update dot position and make it visible
                dot.transform.translation = localPosition
                dot.isEnabled = true
            } else {
                // Hide unused dots
                dot.isEnabled = false
            }
        }
    }
    
    /// Hide all dots (used when tracking is lost)
    func hideAllDots() {
        dotEntities.forEach { $0.isEnabled = false }
        lineContainer.isEnabled = false
    }
    
    /// Show all active dots
    func showAllDots() {
        lineContainer.isEnabled = true
    }
    
    // MARK: - Configuration
    
    /// Update dot appearance properties
    func updateDotAppearance(
        radius: Float? = nil,
        color: UIColor? = nil,
        alpha: Float? = nil
    ) {
        let newRadius = radius ?? dotRadius
        let newColor = color ?? UIColor.red
        let newAlpha = alpha ?? 0.7
        
        // Create new mesh and material if needed
        let shouldUpdateMesh = radius != nil
        let shouldUpdateMaterial = color != nil || alpha != nil
        
        if shouldUpdateMesh || shouldUpdateMaterial {
            let mesh = shouldUpdateMesh ? MeshResource.generateSphere(radius: newRadius) : nil
            let material = shouldUpdateMaterial ? SimpleMaterial(
                color: .init(red: 1, green: 0, blue: 0, alpha: 0.5),
                isMetallic: false
            ) : nil
            
            for dot in dotEntities {
                if let newMesh = mesh {
                    dot.model?.mesh = newMesh
                }
                if let newMaterial = material {
                    dot.model?.materials = [newMaterial]
                }
            }
        }
    }
    
    /// Get the current number of visible dots
    func getVisibleDotCount() -> Int {
        return dotEntities.filter { $0.isEnabled }.count
    }
    
    /// Get the spacing between dots
    func getDotSpacing() -> Float {
        return dotSpacing
    }
    
    /// Get the maximum number of dots that can be displayed
    func getMaxDotCount() -> Int {
        return maxDots
    }
    
    /// Calculate the maximum line length that can be visualized
    func getMaxLineLength() -> Float {
        return Float(maxDots) * dotSpacing
    }
}
