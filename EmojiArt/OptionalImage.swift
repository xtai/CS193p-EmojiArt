//
//  OptionalImage.swift
//  EmojiArt
//
//  Created by Sean Tai on 7/17/20.
//

import SwiftUI

struct OptionalImage: View {
    var uiImage: UIImage?
    
    var body: some View {
        Group {
            if uiImage != nil {
                Image(uiImage: uiImage!)
            }
        }
    }
}
