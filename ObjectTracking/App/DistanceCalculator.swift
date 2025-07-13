// DistanceCalculator.swift
// I3D-stroke-rehab
//
// See the LICENSE.txt file for this sample's licensing information.
//
// Abstract:
// Handles distance calculations between finger position and the headset-to-object line.

import ARKit
import RealityKit
import simd
import QuartzCore

@MainActor
class DistanceCalculator {
    
    private let worldInfo: WorldTrackingProvider
    
    init(worldInfo: WorldTrackingProvider) {
        self.worldInfo = worldInfo
    }
    
    // MARK: - Distance Calculations
    
    /// Calculate the shortest distance from finger position to the headset-to-object line
    func distanceFromFingerToLine(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> Float? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        // Vector from headset to object
        let v = objectPos - headsetPos
        
        // Vector from headset to finger
        let w = fingerWorldPos - headsetPos
        
        // Project finger onto the headset-to-object line
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        
        // Handle edge case where headset and object are at same position
        guard c2 > 0 else {
            return simd_length(w)
        }
        
        // Calculate the parametric position on the line (clamped to [0,1])
        var t = c1 / c2
        t = max(0, min(1, t))
        
        // Find the closest point on the line segment
        let closestPoint = headsetPos + v * t
        
        // Return distance from finger to closest point on line
        return simd_length(fingerWorldPos - closestPoint)
    }
    
    /// Calculate distance between two 3D points
    func distanceBetweenPoints(
        _ point1: SIMD3<Float>,
        _ point2: SIMD3<Float>
    ) -> Float {
        return simd_length(point2 - point1)
    }
    
    /// Calculate the parametric position of finger projection on headset-to-object line
    /// Returns a value between 0 and 1, where 0 is at headset and 1 is at object
    func getFingerProjectionParameter(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> Float? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        // Vector from headset to object
        let v = objectPos - headsetPos
        
        // Vector from headset to finger
        let w = fingerWorldPos - headsetPos
        
        // Project finger onto the headset-to-object line
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        
        // Handle edge case where headset and object are at same position
        guard c2 > 0 else {
            return 0
        }
        
        // Calculate the parametric position on the line (clamped to [0,1])
        let t = c1 / c2
        return max(0, min(1, t))
    }
    
    /// Get the closest point on the headset-to-object line to the finger position
    func getClosestPointOnLine(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        // Vector from headset to object
        let v = objectPos - headsetPos
        
        // Vector from headset to finger
        let w = fingerWorldPos - headsetPos
        
        // Project finger onto the headset-to-object line
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        
        // Handle edge case where headset and object are at same position
        guard c2 > 0 else {
            return headsetPos
        }
        
        // Calculate the parametric position on the line (clamped to [0,1])
        var t = c1 / c2
        t = max(0, min(1, t))
        
        // Return the closest point on the line segment
        return headsetPos + v * t
    }
    
    /// Calculate the perpendicular distance from a point to a line segment
    func perpendicularDistanceToLineSegment(
        point: SIMD3<Float>,
        lineStart: SIMD3<Float>,
        lineEnd: SIMD3<Float>
    ) -> Float {
        let lineVector = lineEnd - lineStart
        let pointVector = point - lineStart
        
        let c1 = simd_dot(pointVector, lineVector)
        let c2 = simd_dot(lineVector, lineVector)
        
        // Handle edge case where line start and end are the same
        guard c2 > 0 else {
            return simd_length(pointVector)
        }
        
        // Calculate the parametric position on the line (clamped to [0,1])
        var t = c1 / c2
        t = max(0, min(1, t))
        
        // Find the closest point on the line segment
        let closestPoint = lineStart + lineVector * t
        
        // Return distance from point to closest point on line
        return simd_length(point - closestPoint)
    }
}
