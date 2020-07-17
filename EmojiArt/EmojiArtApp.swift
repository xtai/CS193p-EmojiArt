//
//  EmojiArtApp.swift
//  EmojiArt
//
//  Created by Sean Tai on 7/16/20.
//

import SwiftUI

@main
struct EmojiArtApp: App {
    var body: some Scene {
        WindowGroup {
            EmojiArtDocumentView(document: EmojiArtDocument())
        }
    }
}
