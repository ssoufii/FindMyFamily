//
//  ContentView.swift
//  FindMyFamily
//
//  Created by Salim Soufi on 2026-08-09.
//

import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var authStatus: AVAuthorizationStatus =
        AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        Group {
            switch authStatus {
            case .authorized:
                ARSessionView()
            case .denied, .restricted:
                CameraAccessDeniedView()
            case .notDetermined:
                Color.black.ignoresSafeArea()
            @unknown default:
                ARSessionView()
            }
        }
        .task {
            guard authStatus == .notDetermined else { return }
            await AVCaptureDevice.requestAccess(for: .video)
            authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
}

struct CameraAccessDeniedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Camera access required")
                .font(.headline)
            Text(
                "Find My Family uses the camera to show AR navigation overlays. "
                + "Enable camera access in Settings to continue."
            )
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
        .padding(32)
    }
}
