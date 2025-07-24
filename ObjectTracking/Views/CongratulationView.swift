//
//  CongratulationView.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 14/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct CongratsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 Congratulations! 🎉")
                .font(.largeTitle)
            Text("You’ve successfully completed the activity.")
                .font(.title2)
            Button("Close") {
                // dismiss window
                #if canImport(SwiftUI)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.windows.first?.rootViewController?.dismiss(animated: true)
                }
                #endif
            }
            .padding(.top)
        }
        .padding()
    }
}
