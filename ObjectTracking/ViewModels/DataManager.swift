//
//  DataManager.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 24/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

enum Step {
    case straight1
    case straight2
    case straight3
    case straight4
    case zigzagBeginner
    case zigzagAdvanced
}

struct TraceAttempt: Codable {
    let attemptNumber: Int
    let timestamp: Date
    let userTrace: [TrackedPoint]
    let headsetPosition: TrackedPoint?
    let objectPosition: TrackedPoint?
    let totalTraceLength: Float
    let maxAmplitude: Float
    let averageAmplitude: Float
    
    struct TrackedPoint: Codable {
        let x: Float
        let y: Float
        let z: Float
        let timestamp: TimeInterval
    }
    
    // Convenience initializer that converts SIMD3<Float> to TrackedPoint
    init(attemptNumber: Int, timestamp: Date, userTrace: [(SIMD3<Float>, TimeInterval)], 
         headsetPosition: SIMD3<Float>?, objectPosition: SIMD3<Float>?, 
         totalTraceLength: Float, maxAmplitude: Float, averageAmplitude: Float) {
        self.attemptNumber = attemptNumber
        self.timestamp = timestamp
        self.userTrace = userTrace.map { TrackedPoint(x: $0.0.x, y: $0.0.y, z: $0.0.z, timestamp: $0.1) }
        self.headsetPosition = headsetPosition.map { TrackedPoint(x: $0.x, y: $0.y, z: $0.z, timestamp: 0) }
        self.objectPosition = objectPosition.map { TrackedPoint(x: $0.x, y: $0.y, z: $0.z, timestamp: 0) }
        self.totalTraceLength = totalTraceLength
        self.maxAmplitude = maxAmplitude
        self.averageAmplitude = averageAmplitude
    }
}

class DataManager: ObservableObject {
    @Published var totalTraceLength: Float = 0
    @Published var maxAmplitude: Float = 0
    @Published var averageAmplitude: Float = 0
    
    @Published var straight1HeadsetPosition: SIMD3<Float>? = nil
    @Published var straight2HeadsetPosition: SIMD3<Float>? = nil
    @Published var straight3HeadsetPosition: SIMD3<Float>? = nil
    @Published var straight4HeadsetPosition: SIMD3<Float>? = nil

    @Published var straight1ObjectPosition: SIMD3<Float>? = nil
    @Published var straight2ObjectPosition: SIMD3<Float>? = nil
    @Published var straight3ObjectPosition: SIMD3<Float>? = nil
    @Published var straight4ObjectPosition: SIMD3<Float>? = nil
    
    @Published var zigzagBeginnerHeadsetPosition: SIMD3<Float>? = nil
    @Published var zigzagBeginnerObjectPosition: SIMD3<Float>? = nil
    @Published var zigzagAdvancedHeadsetPosition: SIMD3<Float>? = nil
    @Published var zigzagAdvancedObjectPosition: SIMD3<Float>? = nil
    
    @Published var currentStep: Step = .straight1
    @Published var currentAttempt: Int = 1
    @Published var stepDidChange: Bool = false

    // Store all attempts for each step
    @Published var straight1Attempts: [TraceAttempt] = []
    @Published var straight2Attempts: [TraceAttempt] = []
    @Published var straight3Attempts: [TraceAttempt] = []
    @Published var straight4Attempts: [TraceAttempt] = []
    @Published var zigzagBeginnerAttempts: [TraceAttempt] = []
    @Published var zigzagAdvancedAttempts: [TraceAttempt] = []

    // Legacy support - current attempt traces
    @Published var straight1UserTrace: [(SIMD3<Float>, TimeInterval)] = []
    @Published var straight2UserTrace: [(SIMD3<Float>, TimeInterval)] = []
    @Published var straight3UserTrace: [(SIMD3<Float>, TimeInterval)] = []
    @Published var straight4UserTrace: [(SIMD3<Float>, TimeInterval)] = []
    @Published var zigzagBeginnerUserTrace: [(SIMD3<Float>, TimeInterval)] = []
    @Published var zigzagAdvancedUserTrace: [(SIMD3<Float>, TimeInterval)] = []
    
    func setTotalTraceLength(_ length: Float) {
        self.totalTraceLength = length
    }
    
    func setMaxAmplitude(_ amplitude: Float) {
        self.maxAmplitude = amplitude
    }
    
    func setAverageAmplitude(_ amplitude: Float) {
        self.averageAmplitude = amplitude
    }
    
    func getCompletedAttempts(for step: Step) -> Int {
        switch step {
        case .straight1: return straight1Attempts.count
        case .straight2: return straight2Attempts.count
        case .straight3: return straight3Attempts.count
        case .straight4: return straight4Attempts.count
        case .zigzagBeginner: return zigzagBeginnerAttempts.count
        case .zigzagAdvanced: return zigzagAdvancedAttempts.count
        }
    }
    
    func isStepComplete(for step: Step) -> Bool {
        return getCompletedAttempts(for: step) >= 10
    }
    
    func canMoveToNextStep() -> Bool {
        return isStepComplete(for: currentStep)
    }
    
    func saveCurrentAttempt() {
        let attempt = TraceAttempt(
            attemptNumber: currentAttempt,
            timestamp: Date(),
            userTrace: getUserTrace(for: currentStep),
            headsetPosition: getHeadsetPosition(for: currentStep),
            objectPosition: getObjectPosition(for: currentStep),
            totalTraceLength: totalTraceLength,
            maxAmplitude: maxAmplitude,
            averageAmplitude: averageAmplitude
        )
        
        switch currentStep {
        case .straight1: straight1Attempts.append(attempt)
        case .straight2: straight2Attempts.append(attempt)
        case .straight3: straight3Attempts.append(attempt)
        case .straight4: straight4Attempts.append(attempt)
        case .zigzagBeginner: zigzagBeginnerAttempts.append(attempt)
        case .zigzagAdvanced: zigzagAdvancedAttempts.append(attempt)
        }
        
        // Move to next attempt or next step
        if currentAttempt < 10 {
            currentAttempt += 1
        } else {
            currentAttempt = 1
            nextStep()
        }
    }
    
    private func getHeadsetPosition(for step: Step) -> SIMD3<Float>? {
        switch step {
        case .straight1: return straight1HeadsetPosition
        case .straight2: return straight2HeadsetPosition
        case .straight3: return straight3HeadsetPosition
        case .straight4: return straight4HeadsetPosition
        case .zigzagBeginner: return zigzagBeginnerHeadsetPosition
        case .zigzagAdvanced: return zigzagAdvancedHeadsetPosition
        }
    }
    
    private func getObjectPosition(for step: Step) -> SIMD3<Float>? {
        switch step {
        case .straight1: return straight1ObjectPosition
        case .straight2: return straight2ObjectPosition
        case .straight3: return straight3ObjectPosition
        case .straight4: return straight4ObjectPosition
        case .zigzagBeginner: return zigzagBeginnerObjectPosition
        case .zigzagAdvanced: return zigzagAdvancedObjectPosition
        }
    }
    
    func nextStep() {
        switch currentStep {
        case .straight1:
            currentStep = .straight2
        case .straight2:
            currentStep = .straight3
        case .straight3:
            currentStep = .straight4
        case .straight4:
            currentStep = .zigzagBeginner
        case .zigzagBeginner:
            currentStep = .zigzagAdvanced
        case .zigzagAdvanced:
            break
        }
        stepDidChange.toggle()
    }

    // Updated to accept and set trace with timestamp data
    func setUserTrace(_ trace: [(SIMD3<Float>, TimeInterval)], for step: Step) {
        switch step {
        case .straight1: straight1UserTrace = trace
        case .straight2: straight2UserTrace = trace
        case .straight3: straight3UserTrace = trace
        case .straight4: straight4UserTrace = trace
        case .zigzagBeginner: zigzagBeginnerUserTrace = trace
        case .zigzagAdvanced: zigzagAdvancedUserTrace = trace
        }
    }

    // Updated to return trace with timestamp data
    func getUserTrace(for step: Step) -> [(SIMD3<Float>, TimeInterval)] {
        switch step {
        case .straight1: return straight1UserTrace
        case .straight2: return straight2UserTrace
        case .straight3: return straight3UserTrace
        case .straight4: return straight4UserTrace
        case .zigzagBeginner: return zigzagBeginnerUserTrace
        case .zigzagAdvanced: return zigzagAdvancedUserTrace
        }
    }
    
    // Helper method to get just the positions without timestamps for legacy uses
    func getUserTracePositions(for step: Step) -> [SIMD3<Float>] {
        return getUserTrace(for: step).map { $0.0 }
    }
    
    // Export the user trace for the given step as a CSV string
    // CSV columns: time,x,y,z
    func exportUserTraceCSV(for step: Step) -> String {
        let trace = getUserTrace(for: step)
        // Header line
        var csvString = "time,x,y,z\n"
        for (position, time) in trace {
            // Format floats and time with fixed decimals for CSV clarity
            let line = String(format: "%.3f,%.6f,%.6f,%.6f\n", time, position.x, position.y, position.z)
            csvString.append(line)
        }
        return csvString
    }
    
    // Export all attempts for all steps as comprehensive CSV
    func exportAllAttemptsToCSV() -> String {
        var csvContent = "Step,AttemptNumber,Timestamp,TotalTraceLength,MaxAmplitude,AverageAmplitude,TracePointX,TracePointY,TracePointZ,TracePointTime\n"
        
        let allSteps: [Step] = [.straight1, .straight2, .straight3, .straight4, .zigzagBeginner, .zigzagAdvanced]
        
        for step in allSteps {
            let attempts = getAttempts(for: step)
            for attempt in attempts {
                let stepName = getStepName(step)
                let baseInfo = "\(stepName),\(attempt.attemptNumber),\(attempt.timestamp),\(attempt.totalTraceLength),\(attempt.maxAmplitude),\(attempt.averageAmplitude)"
                
                for point in attempt.userTrace {
                    csvContent += "\(baseInfo),\(point.x),\(point.y),\(point.z),\(point.timestamp)\n"
                }
            }
        }
        
        return csvContent
    }
    
    func getAttempts(for step: Step) -> [TraceAttempt] {
        switch step {
        case .straight1: return straight1Attempts
        case .straight2: return straight2Attempts
        case .straight3: return straight3Attempts
        case .straight4: return straight4Attempts
        case .zigzagBeginner: return zigzagBeginnerAttempts
        case .zigzagAdvanced: return zigzagAdvancedAttempts
        }
    }
    
    private func getStepName(_ step: Step) -> String {
        switch step {
        case .straight1: return "Straight1"
        case .straight2: return "Straight2"
        case .straight3: return "Straight3"
        case .straight4: return "Straight4"
        case .zigzagBeginner: return "ZigzagBeginner"
        case .zigzagAdvanced: return "ZigzagAdvanced"
        }
    }
}
