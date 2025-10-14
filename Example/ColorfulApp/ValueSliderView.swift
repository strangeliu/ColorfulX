//
//  ValueSliderView.swift
//  ColorfulApp
//
//  Created by qaq on 11/10/2025.
//

import SwiftUI

struct ValueSliderView: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.body.bold())
                Spacer()
                Text(String(format: format, value))
                    .font(.body)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .animation(.interactiveSpring, value: value)

            #if os(tvOS)
                Text("Adjust this value on a supported platform.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            #else
                Slider(value: $value, in: range, step: step)
            #endif
        }
    }
}
