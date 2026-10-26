//
//  OnboardingView.swift
//  googleCalendarWidget
//

import SwiftUI

private enum OnboardingStep {
    case welcome
    case signIn
    case addWidget
    case finished
}

/// The first-launch tour: welcome, sign in, add the widget.
struct OnboardingView: View {
    let onFinish: () -> Void
    let onOpenPane: (String) -> Void

    @State private var step: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    go(to: .signIn)
                }
                .transition(.opacity)

            case .signIn:
                SignInStepView(onContinue: { go(to: .addWidget) })
                    .transition(.opacity)

            case .addWidget:
                FeatureStepView(
                    icon: "rectangle.on.rectangle",
                    title: "Add the Widget",
                    description: "Right-click your desktop and choose Edit Widgets, or open Notification Center and click Edit Widgets. Then find CalWidget and add it.",
                    onContinue: { go(to: .finished) }
                )
                .transition(.opacity)

            case .finished:
                OnboardingFinishView(onFinish: onFinish, onOpenSettings: {
                    onOpenPane("Calendars")
                    onFinish()
                })
            }
        }
        .frame(width: 400, height: 600)
    }

    private func go(to newStep: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.6)) {
            step = newStep
        }
    }
}

private struct WelcomeView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .padding(.bottom, 8)
            Text("CalWidget")
                .font(.system(.largeTitle, design: .default))
                .fontWeight(.semibold)
            Text("Welcome")
                .font(.title)
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)

            Button {
                onGetStarted()
            } label: {
                Text("Get started")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(BorderedProminentButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
        }
    }
}

/// Asks the user to sign in, in the same layout as Dynamic Notch's permission pages.
private struct SignInStepView: View {
    @Environment(AppModel.self) private var model

    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "person.badge.key")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 56)
                .foregroundColor(.accentColor)
                .padding(.top, 32)

            Text("Sign in with Google")
                .font(.title)
                .fontWeight(.semibold)

            Text("CalWidget shows your own events by reading your Google Calendar. Sign in and allow read-only access to your calendar.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.secondary)
                Text("CalWidget can't create, edit, or delete events. Nothing is sent anywhere except between your Mac and Google.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.bottom, 8)
            .padding(.horizontal)

            if model.isSigningIn {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Finish signing in in your browser…")
                        .foregroundStyle(.secondary)
                    Button("Cancel") { model.cancelSignIn() }
                        .buttonStyle(.bordered)
                }
                .padding(.top, 10)
            } else {
                HStack {
                    Button("Not Now") { onContinue() }
                        .buttonStyle(.bordered)
                    Button("Sign In") { model.beginSignIn() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.isWorking)
                }
                .padding(.top, 10)
            }

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
        .onChange(of: model.isSignedIn) { _, signedIn in
            if signedIn { onContinue() }
        }
    }
}

/// A tour step with an icon, a short explanation and a Continue button.
private struct FeatureStepView: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 56)
                .foregroundColor(.accentColor)
                .padding(.top, 32)

            Text(title)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(description)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Continue") { onContinue() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

private struct OnboardingFinishView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding()

            Text("You're All Set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Pick which calendars the widget shows any time in the app. To change a widget's style, right-click it and choose Edit Widget.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                Button(action: onOpenSettings) {
                    Label("Choose Calendars", systemImage: "list.bullet")
                        .controlSize(.large)
                }
                .controlSize(.large)

                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
        )
    }
}

#Preview {
    OnboardingView(onFinish: {}, onOpenPane: { _ in })
        .environment(AppModel())
}
