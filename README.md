# Passkey Context Scanner

An experimental iOS app that analyses the visible context around cross-device passkey QR codes before the user proceeds with the normal authentication flow.

The scanner uses on-device QR detection and OCR to examine visible identity, domain, purpose, authentication language, persuasion cues, context association, and missing evidence. It produces an explainable result:

- `CONSISTENT` — no obvious contextual conflict was found;
- `SUSPICIOUS` — strong misleading or contradictory evidence was found;
- `UNCERTAIN` — there is not enough relevant evidence for a clear result.

`CONSISTENT` does not mean that a QR code is verified or safe.

## Features

- Live camera scanning with QR bounding-box and stability feedback.
- Static screenshot and photo analysis.
- Full-frame and QR-centred OCR using Apple Vision.
- Privacy-preserving identification of FIDO, URL, other, and unknown QR formats.
- Deterministic, traceable context extraction and classification rules.
- Optional adaptive clarification about user intent and the receiving computer.
- Separate participant-facing guidance and researcher diagnostics.
- Local evaluation records with JSON persistence and CSV export.

## Technology

- Swift and SwiftUI
- iOS 17 or later
- AVFoundation for camera capture and live QR metadata
- Apple Vision for QR detection and text recognition
- PhotosUI for static-image selection
- XCTest for unit and regression tests

The app has no external backend and does not require third-party dependencies.

## Build and run

1. Open `PasskeyContextScanner.xcodeproj` in Xcode.
2. Select an iOS 17+ simulator or a signed physical iPhone target.
3. Build and run the `PasskeyContextScanner` scheme.
4. Allow camera or photo-library access when requested.

A physical iPhone is recommended for testing live focus, orientation, distance, glare, and capture performance. Static-image analysis and deterministic logic can be tested in the simulator.

## Testing

Run the `PasskeyContextScannerTests` target with **Product → Test** in Xcode (`⌘U`).

The tests cover QR and OCR pipeline behaviour, domain and purpose extraction, context association, classifier rules, clarification flow, evaluation logging, and failure handling.

## Privacy and security boundary

- Image analysis is performed locally.
- Raw images are not stored by default.
- Complete FIDO QR payloads are not retained or exported.
- QR content is not automatically opened or executed.
- Evaluation export requires an explicit share action.

The scanner assesses visible contextual evidence only. It cannot cryptographically verify the relying party, inspect the protected WebAuthn request, or determine who controls the computer session receiving the authentication.
