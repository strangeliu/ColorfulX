//
//  ViewController.swift
//  AuroraGlow
//
//  Created by qaq on 13/10/2025.
//

import Cocoa
import ColorfulX

class ViewController: NSViewController {
    let subview = AuroraGlowView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(subview)

        subview.wantsLayer = true
        subview.layer?.borderColor = NSColor.blue.withAlphaComponent(0.1).cgColor
        subview.layer?.borderWidth = 2.0
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subview.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            subview.widthAnchor.constraint(equalToConstant: 300),
            subview.heightAnchor.constraint(equalToConstant: 200),
        ])
    }
}
