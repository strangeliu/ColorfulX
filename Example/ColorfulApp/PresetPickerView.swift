//
//  PresetPickerView.swift
//  ColorfulApp
//
//  Created by qaq on 11/10/2025.
//

import ColorfulX
import SwiftUI

struct PresetPickerView: View {
    @Binding var preset: ColorfulPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preset")
                    .font(.body.bold())
                    .padding(.horizontal, 4)
                Spacer()
                ColorPaletteView(colors: preset.colors)
            }

            Picker("", selection: $preset) {
                ForEach(ColorfulPreset.allCases, id: \.self) { option in
                    Text(option.hint).tag(option)
                }
            }
            #if os(macOS)
            .pickerStyle(.menu)
            #elseif os(tvOS)
            .pickerStyle(.automatic)
            #else
            .pickerStyle(.wheel)
            #endif
        }
    }
}

private struct ColorPaletteView: View {
    let colors: [ColorElement]
    let circleSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            ForEach(colors, id: \.self) { color in
                Circle()
                    .fill(Color(color))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}
