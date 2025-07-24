//
//  DataManager.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 24/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import Foundation
import SwiftUI

class DataManager: ObservableObject {
    @Published var totalTraceLength: Float = 0
    
    func setTotalTraceLength(_ length: Float) {
        self.totalTraceLength = length
    }
}
