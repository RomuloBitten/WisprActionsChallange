//
//  SpeechRecognitionView.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import SwiftUI
import UIKit

struct SpeechRecognitionView<ViewModel: SpeechRecognitionViewModeling>: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ViewModel

    init(viewModel: ViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        ScrollView(showsIndicators: false) {
                            statusContent
                                .padding(.top, 8)
                                .padding(.bottom, 220)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                        VStack(spacing: 0) {
                            SpeechWaveView(
                                soundHeights: viewModel.soundHeights,
                                isExpanded: viewModel.isRecognizing,
                                sourceMinHeight: 6,
                                sourceMaxHeight: 32,
                                barWidth: 8,
                                maxBarHeight: 120,
                                barSpacing: 6
                            )
                            .padding(.bottom, 22)

                            microphoneButton
                        }
                    }
                    .frame(height: geometry.size.height / 2)
                    .frame(maxWidth: .infinity)

                    transcriptSection
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(screenBackground)
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("MapAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(navigationBarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            viewModel.viewDidAppear()
        }
    }

    private var microphoneButton: some View {
        Button(action: viewModel.didTapMicrophoneButton) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: microphoneButtonGradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                    }

                Image(systemName: "mic.fill")
                    .font(.system(size: 62, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 180, height: 180)
            .shadow(color: Color(red: 0.05, green: 0.78, blue: 0.78).opacity(0.38), radius: 26, y: 10)
            .shadow(color: Color.white.opacity(0.55), radius: 16, y: -6)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isMicrophoneButtonEnabled)
        .accessibilityLabel("Start speech recognition")
    }

    private var transcriptSection: some View {
        ScrollView(showsIndicators: false) {
            if viewModel.recognizedText.isEmpty {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 1, maxHeight: .infinity)
            } else {
                Text(viewModel.recognizedText)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.97, blue: 0.94),
                Color(red: 0.95, green: 0.93, blue: 0.89)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var navigationBarBackground: Color {
        Color(red: 0.98, green: 0.97, blue: 0.94)
    }

    @ViewBuilder
    private var statusContent: some View {
        if let screenError = viewModel.screenError {
            VStack(spacing: 12) {
                Text(screenError.message)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                if let settingsButtonTitle = screenError.settingsButtonTitle {
                    Button(settingsButtonTitle) {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }

        if !viewModel.isRecognizing, let resolvedIntentDebugText = viewModel.resolvedIntentDebugText {
            Text(resolvedIntentDebugText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }

        if !viewModel.isRecognizing, let intentErrorMessage = viewModel.intentErrorMessage {
            Text(intentErrorMessage)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var microphoneButtonGradientColors: [Color] {
        if viewModel.isMicrophoneButtonEnabled {
            return [
                Color(red: 0.18, green: 0.87, blue: 0.97),
                Color(red: 0.04, green: 0.70, blue: 0.66)
            ]
        }

        return [
            Color(red: 0.78, green: 0.78, blue: 0.78),
            Color(red: 0.58, green: 0.58, blue: 0.58)
        ]
    }
}

#Preview {
    SpeechRecognitionView(
        viewModel: SpeechRecognitionViewModel(
            speechRecognizer: MockedSpeechRecognizer(),
            intentResolver: MockedIntentResolver()
        )
    )
}
