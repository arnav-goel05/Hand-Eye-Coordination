//
//  DataManager.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 24/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

enum step {
    case straight
    case zigzagBeginner
    case zigzagAdvanced
}

class DataManager: ObservableObject {
    @Published var totalTraceLength: Float = 0
    @Published var maxAmplitude: Float = 0
    @Published var averageAmplitude: Float = 0
    
    @Published var straightHeadsetPosition: SIMD3<Float>? = nil
    @Published var straightObjectPosition: SIMD3<Float>? = nil
    @Published var zigzagBeginnerHeadsetPosition: SIMD3<Float>? = nil
    @Published var zigzagBeginnerObjectPosition: SIMD3<Float>? = nil
    @Published var zigzagAdvancedHeadsetPosition: SIMD3<Float>? = nil
    @Published var zigzagAdvancedObjectPosition: SIMD3<Float>? = nil
    
    @Published var currentStep: step = .straight
    @Published var stepDidChange: Bool = false

    // Changed from [SIMD3<Float>] to [(SIMD3<Float>, TimeInterval)] to store positions along with their timestamps
    @Published var straightUserTrace: [(SIMD3<Float>, TimeInterval)] = []
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
        if currentStep == .straight {
            currentStep = .zigzagBeginner
        } else if currentStep == .zigzagBeginner {
            currentStep = .zigzagAdvanced
        }
        stepDidChange.toggle()
    }

    // Updated to accept and set trace with timestamp data
    func setUserTrace(_ trace: [(SIMD3<Float>, TimeInterval)], for step: step) {
        switch step {
        case .straight: straightUserTrace = trace
        case .zigzagBeginner: zigzagBeginnerUserTrace = trace
        case .zigzagAdvanced: zigzagAdvancedUserTrace = trace
        }
    }

    // Updated to return trace with timestamp data
    func getUserTrace(for step: step) -> [(SIMD3<Float>, TimeInterval)] {
        switch step {
        case .straight: return straightUserTrace
        case .zigzagBeginner: return zigzagBeginnerUserTrace
        case .zigzagAdvanced: return zigzagAdvancedUserTrace
        }
    }
    
    // Helper method to get just the positions without timestamps for legacy uses
    func getUserTracePositions(for step: step) -> [SIMD3<Float>] {
        return getUserTrace(for: step).map { $0.0 }
    }
    
    // Export the user trace for the given step as a CSV string
    // CSV columns: time,x,y,z
    func exportUserTraceCSV(for step: step) -> String {
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
