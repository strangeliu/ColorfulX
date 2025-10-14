//
//  ControlSurface.swift
//  ColorfulApp
//
//  Created by qaq on 11/10/2025.
//

import ColorfulX
import SwiftUI

struct ControlSurface: View {
    @Binding var preset: ColorfulPreset
    @Binding var speed: Double
    @Binding var bias: Double
    @Binding var noise: Double
    @Binding var duration: TimeInterval
    @Binding var scale: Double
    @Binding var frame: Int

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                PresetPickerView(preset: $preset)

                Divider()

                ValueSliderView(title: "Speed", value: $speed, range: 0.0 ... 10.0, step: 0.1, format: "%.1f")
                ValueSliderView(title: "Bias", value: $bias, range: 0.00001 ... 0.01, step: 0.00001, format: "%.5f")
                ValueSliderView(title: "Noise", value: $noise, range: 0 ... 64, step: 1, format: "%.0f")
                ValueSliderView(title: "Transition", value: $duration, range: 0.0 ... 10.0, step: 0.1, format: "%.1f")
                ValueSliderView(title: "Scale", value: $scale, range: 0.001 ... 2.0, step: 0.001, format: "%.3f")
                FramePickerControl(frame: $frame)
            }
            .padding(24)
        }
        .frame(maxWidth: 444, maxHeight: 444)
        #if !os(visionOS)
            .glassEffect(.regular, in: ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true))
        #endif
            .clipShape(ConcentricRectangle(corners: .concentric(minimum: 16), isUniform: true))
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
