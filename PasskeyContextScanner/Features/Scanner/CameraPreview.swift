import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let detections: [LiveQRCodeDetection]
    let isStable: Bool

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.updateOverlays(detections, isStable: isStable)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.updateOverlays(detections, isStable: isStable)
    }
}

final class CameraPreviewView: UIView {
    private var overlayLayers: [CAShapeLayer] = []
    private var currentDetections: [LiveQRCodeDetection] = []
    private var currentStability = false

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            preconditionFailure("CameraPreviewView requires AVCaptureVideoPreviewLayer.")
        }
        return layer
    }

    func updateOverlays(
        _ detections: [LiveQRCodeDetection],
        isStable: Bool
    ) {
        currentDetections = detections
        currentStability = isStable
        drawOverlays()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawOverlays()
    }

    private func drawOverlays() {
        overlayLayers.forEach { $0.removeFromSuperlayer() }
        overlayLayers = currentDetections.map { detection in
            let normalizedRect = CGRect(
                x: detection.metadataBoundingBox.x,
                y: detection.metadataBoundingBox.y,
                width: detection.metadataBoundingBox.width,
                height: detection.metadataBoundingBox.height
            )
            let convertedRect = previewLayer.layerRectConverted(
                fromMetadataOutputRect: normalizedRect
            )
            let overlay = CAShapeLayer()
            overlay.frame = bounds
            overlay.path = UIBezierPath(
                roundedRect: convertedRect,
                cornerRadius: 10
            ).cgPath
            overlay.fillColor = UIColor.clear.cgColor
            overlay.strokeColor = (
                currentStability ? UIColor.systemGreen : UIColor.systemYellow
            ).cgColor
            overlay.lineWidth = 4
            previewLayer.addSublayer(overlay)
            return overlay
        }
    }
}
