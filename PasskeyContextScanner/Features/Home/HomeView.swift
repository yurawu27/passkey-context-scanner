import SwiftUI

struct HomeView: View {
    @AppStorage("applicationMode") private var applicationModeRawValue = ApplicationMode.participant.rawValue
    @AppStorage("participantIntroductionEnabled") private var introductionEnabled = true
    @AppStorage("hasSeenParticipantIntroduction") private var hasSeenIntroduction = false
    @State private var showsIntroduction = false

    private var applicationMode: ApplicationMode {
        ApplicationMode(rawValue: applicationModeRawValue) ?? .participant
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        ScannerView(applicationMode: applicationMode)
                    } label: {
                        Label("Live Scanner", systemImage: "qrcode.viewfinder")
                    }

                    NavigationLink {
                        StaticImageAnalysisView(
                            applicationMode: applicationMode,
                            participantIntroductionCompleted: hasSeenIntroduction
                        )
                    } label: {
                        Label("Static Image Analysis", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("Passkey Context Scanner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ApplicationModeSettingsView(
                            applicationModeRawValue: $applicationModeRawValue,
                            introductionEnabled: $introductionEnabled,
                            hasSeenIntroduction: $hasSeenIntroduction
                        )
                    } label: {
                        Label("Mode settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsIntroduction = true
                    } label: {
                        Label("How the scanner works", systemImage: "questionmark.circle")
                    }
                }
            }
            .onAppear {
                if applicationMode == .participant,
                   introductionEnabled,
                   !hasSeenIntroduction {
                    showsIntroduction = true
                }
            }
            .sheet(isPresented: $showsIntroduction) {
                PasskeyContextIntroductionView {
                    hasSeenIntroduction = true
                    showsIntroduction = false
                }
                .interactiveDismissDisabled()
            }
        }
    }
}

private struct ApplicationModeSettingsView: View {
    @Binding var applicationModeRawValue: String
    @Binding var introductionEnabled: Bool
    @Binding var hasSeenIntroduction: Bool

    var body: some View {
        Form {
            Section("Application mode") {
                Picker("Mode", selection: $applicationModeRawValue) {
                    ForEach(ApplicationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Participant") {
                Text("Shows the minimal security intervention and asks at most one outcome-relevant question.")
            }

            Section("Researcher") {
                Text("Exposes full intent collection, classifier details, OCR observations, evaluation labels, and dataset export. Use only for controlled dissertation testing.")
            }

            Section("Participant introduction") {
                Toggle("Show on first use", isOn: $introductionEnabled)
                Button("Reset introduction") {
                    hasSeenIntroduction = false
                }
                Text("Treat introduction exposure as a study condition because it may teach participants about the attack before testing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Mode Settings")
    }
}

private struct PasskeyContextIntroductionView: View {
    let dismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Before you scan", systemImage: "iphone.and.arrow.forward")
                        .font(.title2.bold())

                    Text("Approving a passkey QR request signs in the computer displaying the code.")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("What this scanner does") {
                    Label("Checks the visible service, purpose, instructions, and warning signs around the QR code.", systemImage: "text.viewfinder")
                    Label("Helps you notice when the visible explanation conflicts with the action you intended.", systemImage: "exclamationmark.bubble")
                }

                Section("Important limitation") {
                    Text("The scanner cannot verify the protected passkey request or who controls the computer session. Always check the service named by the phone before approving.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Button("Continue", action: dismiss)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("How It Works")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss)
                }
            }
        }
    }
}

private struct ResultSummaryRow: View {
    let result: ScanResult

    var body: some View {
        let presentation = SecurityResultPresentation.make(for: result)
        VStack(alignment: .leading, spacing: 6) {
            Text(presentation.headline)
                .font(.headline)
            Text(presentation.primaryReason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
