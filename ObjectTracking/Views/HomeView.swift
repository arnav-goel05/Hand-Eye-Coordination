/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main user interface.
*/

import SwiftUI
import ARKit
import RealityKit
import UniformTypeIdentifiers

struct HomeView: View {
    @Bindable var appState: AppState
    let immersiveSpaceIdentifier: String
    
    let referenceObjectUTType = UTType("com.apple.arkit.referenceobject")!
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject var dataManager: DataManager
    
    @State private var fileImporterIsOpen = false
    @State private var showSummary = false
    
    @State var selectedReferenceObjectID: ReferenceObject.ID?
    
    @State private var titleText = ""
    @State private var isTitleFinished = false
    private let finalTitle = "Hand-Eye Coordination Assessment"
    
    var body: some View {
        NavigationStack {
            VStack {
                if appState.canEnterImmersiveSpace {
                    if !appState.isImmersiveSpaceOpened {
                        VStack(spacing: 50) {
                            Text(finalTitle)
                                .font(.system(size: 45, weight: .bold, design: .monospaced))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .hidden()
                                .overlay(alignment: .leading) {
                                    Text(titleText)
                                        .font(.system(size: 45, weight: .bold, design: .monospaced))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            
                            Text("Within this assessment, there are six challenges you must complete in increasing order of difficulty. All the best!!!")
                                .subtitleTextStyle()
                                .disabled(!isTitleFinished)
                                .opacity(isTitleFinished ? 1 : 0)
                                .animation(.easeIn(duration: 0.4), value: isTitleFinished)
                                .allowsHitTesting(isTitleFinished)
                            
                            Button(action: {
                                Task {
                                    switch await openImmersiveSpace(id: immersiveSpaceIdentifier) {
                                    case .opened:
                                        break
                                    case .error:
                                        print("An error occurred when trying to open the immersive space \(immersiveSpaceIdentifier)")
                                    case .userCancelled:
                                        print("The user declined opening immersive space \(immersiveSpaceIdentifier)")
                                    @unknown default:
                                        break
                                    }
                                }
                            }) {
                                Text("Start Assessment")
                                    .buttonTextStyle()
                            }
                            .disabled(!isTitleFinished)
                            .opacity(isTitleFinished ? 1 : 0)
                            .animation(.easeIn(duration: 0.4), value: isTitleFinished)
                            .allowsHitTesting(isTitleFinished)
                        }
                        .typeText(
                            text: $titleText,
                            finalText: finalTitle,
                            isFinished: $isTitleFinished,
                            isAnimated: !isTitleFinished
                        )
                        .padding(.horizontal, 100)
                    } else {
                        VStack(spacing: 50) {
                            
                            let challengeLabel: String = {
                                switch dataManager.currentStep {
                                case .straight1:
                                    return "Challenge 1: Straight Line 1\nTrace using your index finger from the green dot to the red dot."
                                case .straight2:
                                    return "Challenge 2: Straight Line 2\nTrace using your index finger from the green dot to the red dot."
                                case .straight3:
                                    return "Challenge 3: Straight Line 3\nTrace using your index finger from the green dot to the red dot."
                                case .straight4:
                                    return "Challenge 4: Straight Line 4\nTrace using your index finger from the green dot to the red dot."
                                case .zigzagBeginner:
                                    return "Challenge 5: Beginner ZigZag Line\nTrace using your index finger from the green dot to the red dot."
                                case .zigzagAdvanced:
                                    return "Challenge 6: Advanced ZigZag Line\nTrace using your index finger from the green dot to the red dot."
                                }
                            }()
                            
                            Text(challengeLabel)
                                .subtitleTextStyle()
                            
                            HStack(spacing: 50) {
//                                Button(action: {
//                                    //TODO
//                                }) {
//                                    Text("Reset")
//                                        .buttonTextStyle()
//                                }
                                if dataManager.currentStep == .straight1 || dataManager.currentStep == .straight2 || dataManager.currentStep == .straight3 || dataManager.currentStep == .straight4 || dataManager.currentStep == .zigzagBeginner {
                                    Button(action: {
                                        Task {
                                            dataManager.nextStep()
                                        }
                                    }) {
                                        Text("Next")
                                            .buttonTextStyle()
                                    }
                                } else {
                                    Button(action: {
                                        Task {
                                            await dismissImmersiveSpace()
                                            appState.didLeaveImmersiveSpace()
                                            showSummary = true
                                        }
                                    }) {
                                        Text("Complete")
                                            .buttonTextStyle()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 100)
                    }
                } else {
                    InfoLabel(appState: appState)
                        .padding(.horizontal, 30)
                        .frame(minWidth: 400, minHeight: 300)
                        .fixedSize()
                }
            }
            .onChange(of: scenePhase, initial: true) {
                print("HomeView scene phase: \(scenePhase)")
                if scenePhase == .active {
                    Task {
                        // When returning from the background, check if the authorization has changed.
                        await appState.queryWorldSensingAuthorization()
                    }
                } else {
                    // Make sure to leave the immersive space if this view is no longer active
                    // - such as when a person closes this view - otherwise they may be stuck
                    // in the immersive space without the controls this view provides.
                    if appState.isImmersiveSpaceOpened {
                        Task {
                            await dismissImmersiveSpace()
                            appState.didLeaveImmersiveSpace()
                        }
                    }
                }
            }
            .onChange(of: appState.providersStoppedWithError, { _, providersStoppedWithError in
                // Immediately close the immersive space if an error occurs.
                if providersStoppedWithError {
                    if appState.isImmersiveSpaceOpened {
                        Task {
                            await dismissImmersiveSpace()
                            appState.didLeaveImmersiveSpace()
                        }
                    }
                    
                    appState.providersStoppedWithError = false
                }
            })
            .task {
                // Ask for authorization before a person attempts to open the immersive space.
                // This gives the app opportunity to respond gracefully if authorization isn't granted.
                if appState.allRequiredProvidersAreSupported {
                    await appState.requestWorldSensingAuthorization()
                }
            }
            .task {
                // Start monitoring for changes in authorization, in case a person brings the
                // Settings app to the foreground and changes authorizations there.
                await appState.monitorSessionEvents()
            }
            .navigationDestination(isPresented: $showSummary) {
                SummaryView()
            }
        }
    }
}

