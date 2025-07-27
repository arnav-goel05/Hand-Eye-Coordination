//
//  Styles.swift
//  I3D-on-call-training
//
//  Created by Interactive 3D Design on 14/7/25.
//

import SwiftUI

struct ButtonTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 27, weight: .semibold, design: .rounded))
            .frame(minWidth: 250, minHeight: 50)
            .padding()
            .cornerRadius(10)
    }
}

struct TitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 35, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .padding()
    }
}

struct SubtitleTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 30, weight: .regular, design: .rounded))
            .multilineTextAlignment(.center)
            .padding(0)
    }
}

extension View {
    func buttonTextStyle() -> some View {
        self.modifier(ButtonTextStyle())
    }
}

extension View {
    func titleTextStyle() -> some View {
        self.modifier(TitleTextStyle())
    }
}

extension View {
    func subtitleTextStyle() -> some View {
        self.modifier(SubtitleTextStyle())
    }
}
