//
//  ARSessionView.swift
//  FindMyFamily
//
//  Created by Salim Soufi on 2026-08-09.
//
//  M0-1: opens a live ARKit world-tracking session.
//  World alignment is gravityAndHeading so that (1,0,0) = east,
//  (0,1,0) = up, (0,0,-1) = north. All AR code in this project
//  assumes this frame — restate it at every conversion site.

import ARKit
import RealityKit
import SwiftUI

struct ARSessionView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        // East-Up-South frame: north = negative Z.
        config.worldAlignment = .gravityAndHeading

        arView.session.run(config)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
