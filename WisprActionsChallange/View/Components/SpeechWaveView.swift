//
//  SpeechWaveView.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import SwiftUI

struct SpeechWaveView: View {
    private let soundHeights: [CGFloat]
    private let isExpanded: Bool
    private let sourceMinHeight: CGFloat
    private let sourceMaxHeight: CGFloat
    private let barWidth: CGFloat
    private let minBarHeight: CGFloat
    private let maxBarHeight: CGFloat
    private let barSpacing: CGFloat
    private let speechStepInterval: Double

    init(
        soundHeights: [CGFloat],
        isExpanded: Bool,
        sourceMinHeight: CGFloat = 6,
        sourceMaxHeight: CGFloat = 32,
        barWidth: CGFloat = 4,
        minBarHeight: CGFloat = 5,
        maxBarHeight: CGFloat = 30,
        barSpacing: CGFloat = 3,
        speechStepInterval: Double = 0.12
    ) {
        self.soundHeights = soundHeights
        self.isExpanded = isExpanded
        self.sourceMinHeight = sourceMinHeight
        self.sourceMaxHeight = sourceMaxHeight
        self.barWidth = barWidth
        self.minBarHeight = minBarHeight
        self.maxBarHeight = maxBarHeight
        self.barSpacing = barSpacing
        self.speechStepInterval = speechStepInterval
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(Array(soundHeights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(Color.red)
                    .frame(
                        width: barWidth,
                        height: scaledHeight(for: height)
                    )
                    .animation(.easeInOut(duration: speechStepInterval), value: height)
            }
        }
        .frame(height: maxBarHeight)
        .opacity(isExpanded ? 1.0 : 0.0)
        .accessibilityHidden(true)
    }

    private func scaledHeight(for height: CGFloat) -> CGFloat {
        let clampedHeight = min(max(height, sourceMinHeight), sourceMaxHeight)
        let sourceRange = max(sourceMaxHeight - sourceMinHeight, 1)
        let normalizedHeight = (clampedHeight - sourceMinHeight) / sourceRange
        return minBarHeight + ((maxBarHeight - minBarHeight) * normalizedHeight)
    }
}

#Preview {
    SpeechWaveView(
        soundHeights: [7, 12, 19, 28, 20, 13, 8, 11, 22, 27, 16, 9],
        isExpanded: true,
        barWidth: 5,
        maxBarHeight: 34
    )
}
