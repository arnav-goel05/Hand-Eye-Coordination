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
    @Published var stepDidChange: Bool = false

    // Changed from [SIMD3<Float>] to [(SIMD3<Float>, TimeInterval)] to store positions along with their timestamps
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
}
