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

    func distanceFromFingerToLine(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> Float? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        let v = objectPos - headsetPos
        let w = fingerWorldPos - headsetPos
        
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)

        guard c2 > 0 else {
            return simd_length(w)
        }

        var t = c1 / c2
        t = max(0, min(1, t))
        
        let closestPoint = headsetPos + v * t

        return simd_length(fingerWorldPos - closestPoint)
    }
    
    func distanceBetweenPoints(
        _ point1: SIMD3<Float>,
        _ point2: SIMD3<Float>
    ) -> Float {
        return simd_length(point2 - point1)
    }

    func getFingerProjectionParameter(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> Float? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        let v = objectPos - headsetPos
        let w = fingerWorldPos - headsetPos

        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)
        
        guard c2 > 0 else {
            return 0
        }
        
        let t = c1 / c2
        return max(0, min(1, t))
    }
    
    func getClosestPointOnLine(
        fingerWorldPos: SIMD3<Float>,
        objectWorldPos: SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard let devicePose = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        
        let headsetPos = Transform(matrix: devicePose.originFromAnchorTransform).translation
        let objectPos = objectWorldPos
        
        let v = objectPos - headsetPos
        let w = fingerWorldPos - headsetPos
        
        let c1 = simd_dot(w, v)
        let c2 = simd_dot(v, v)

        guard c2 > 0 else {
            return headsetPos
        }

        var t = c1 / c2
        t = max(0, min(1, t))

        return headsetPos + v * t
    }
    
    func perpendicularDistanceToLineSegment(
        point: SIMD3<Float>,
        lineStart: SIMD3<Float>,
        lineEnd: SIMD3<Float>
    ) -> Float {
        let lineVector = lineEnd - lineStart
        let pointVector = point - lineStart
        
        let c1 = simd_dot(pointVector, lineVector)
        let c2 = simd_dot(lineVector, lineVector)
        
        guard c2 > 0 else {
            return simd_length(pointVector)
        }
        
        var t = c1 / c2
        t = max(0, min(1, t))

        let closestPoint = lineStart + lineVector * t

        return simd_length(point - closestPoint)
    }
}
