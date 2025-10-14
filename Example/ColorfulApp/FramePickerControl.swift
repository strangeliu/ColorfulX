//
//  FramePickerControl.swift
//  ColorfulApp
//
//  Created by qaq on 11/10/2025.
//

import SwiftUI

struct FramePickerControl: View {
    @Binding var frame: Int

    #if os(macOS)
        let selections: [Int] = [0, 15, 30, 60]
    #else
        let selections: [Int] = [0, 15, 30, 60, 120]
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Frame Limit")
                    .font(.body.bold())
                Spacer()
            }

            Picker("", selection: $frame) {
                ForEach(selections, id: \.self) { option in
                    Text(option == 0 ? "MAX" : "\(option) FPS")
                        .font(.footnote)
                        .fontDesign(.monospaced)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
