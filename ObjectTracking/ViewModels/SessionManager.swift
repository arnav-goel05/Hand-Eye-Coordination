//
//  SessionManager.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 25/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

class SessionManager: ObservableObject {
    @Published var sessions: [String: DataManager] = [:]

    func createSession(named name: String) {
        sessions[name] = DataManager()
    }

    func sessionData(for name: String) -> DataManager? {
        return sessions[name]
    }
}
