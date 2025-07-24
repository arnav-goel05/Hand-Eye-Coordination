//
//  CongratulationView.swift
//  ObjectTracking
//
//  Created by Interactive 3D Design on 14/7/25.
//  Copyright © 2025 Apple. All rights reserved.
//

import SwiftUI

struct SummaryView: View {
    
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Summary!")
                .font(.largeTitle)
            Text("Total finger tracking distance: \(String(format: "%.3f", dataManager.totalTraceLength)) m")
        }
        .padding()
    }
}
