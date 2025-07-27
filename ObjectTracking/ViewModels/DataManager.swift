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

    @Published var straightUserTrace: [SIMD3<Float>] = []
    @Published var zigzagBeginnerUserTrace: [SIMD3<Float>] = []
    @Published var zigzagAdvancedUserTrace: [SIMD3<Float>] = []
    
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

    func setUserTrace(_ trace: [SIMD3<Float>], for step: step) {
        switch step {
        case .straight: straightUserTrace = trace
        case .zigzagBeginner: zigzagBeginnerUserTrace = trace
        case .zigzagAdvanced: zigzagAdvancedUserTrace = trace
        }
    }

    func getUserTrace(for step: step) -> [SIMD3<Float>] {
        switch step {
        case .straight: return straightUserTrace
        case .zigzagBeginner: return zigzagBeginnerUserTrace
        case .zigzagAdvanced: return zigzagAdvancedUserTrace
        }
    }
}

