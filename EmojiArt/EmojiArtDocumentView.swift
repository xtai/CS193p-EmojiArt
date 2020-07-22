//
//  EmojiArtDocumentView.swift
//  EmojiArt
//
//  Created by Sean Tai on 7/16/20.
//

import SwiftUI

struct EmojiArtDocumentView: View {
    @ObservedObject var document: EmojiArtDocument
    
    @State private var showingAlert = false
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // placeholder for emoji picker toolbar Height
                    Text(" ")
                        .font(Font.system(size: self.defaultEmojiSize))
                        .padding(.top, geometry.safeAreaInsets.top)
                        .padding([.horizontal, .bottom])
                    content()
                    .edgesIgnoringSafeArea(.all)
                }
                .background(Color.gray)
                .edgesIgnoringSafeArea(.all)
                toolbar(geometry: geometry)
            }
        }
    }

    
    // MARK: - Content Layer
    
    @ViewBuilder
    private func content() -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.gray.overlay(
                    OptionalImage(uiImage: self.document.backgroundImage)
                        .scaleEffect(self.zoomScale)
                        .offset(self.panOffset)
                ).gesture(self.doubleTapToZoom(in: geometry.size))
                ForEach(self.document.emojis) { emoji in
                    Text(emoji.text)
                        .padding(2)
                        .background(Color.blue.opacity(self.selectedEmojis.contains(matching: emoji) ? 0.1 : 0))
                        .border(Color.blue, width: self.selectedEmojis.contains(matching: emoji) ? 2 : 0)
                        .font(animatableWithSize: self.scale(for: emoji))
                        .position(self.position(for: emoji, in: geometry.size))
                        .gesture(self.tapToSelect(emoji: emoji))
                        .gesture(self.panEmojiGesture(emoji: emoji))
                }
            }.gesture(self.panGesture())
            .gesture(self.zoomGesture())
            .gesture(self.tapToDeselect())
            .onDrop(of: ["public.image","public.text"], isTargeted: nil) { providers, location in
                // SwiftUI bug (as of 13.4)? the location is supposed to be in our coordinate system
                // however, the y coordinate appears to be in the global coordinate system
                var location = CGPoint(x: location.x, y: geometry.convert(location, from: .global).y)
                location = CGPoint(x: location.x - geometry.size.width/2, y: location.y - geometry.size.height/2)
                location = CGPoint(x: location.x - self.panOffset.width, y: location.y - self.panOffset.height)
                location = CGPoint(x: location.x / self.zoomScale, y: location.y / self.zoomScale)
                return self.drop(providers: providers, at: location)
            }
        }
    }

    
    // MARK: - Toolbar Layer

    @ViewBuilder
    private func toolbar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            HStack {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(EmojiArtDocument.palette.map { String($0) }, id: \.self) { emoji in
                            Text(emoji)
                                .font(Font.system(size: self.defaultEmojiSize))
                                .onDrag { NSItemProvider(object: emoji as NSString) }
                        }
                    }
                }
                deleteButton()
            }
            .padding(.top, geometry.safeAreaInsets.top)
            .padding([.horizontal, .bottom])
            .background(Blur(style: .systemThinMaterial))
            Spacer()
//            debugger()
        }.edgesIgnoringSafeArea([.horizontal, .top])
    }
    
    @ViewBuilder
    private func deleteButton() -> some View {
        Button(action: {
            withAnimation (.easeInOut) {
                showingAlert = true
            }
        }) {
            Group {
                if selectedEmojis.count <= 1 {
                    Label("Remove Emoji", systemImage: "trash")
                } else {
                    Label("Remove \(selectedEmojis.count) Emojis", systemImage: "trash")
                }
            }.padding()
            .foregroundColor(Color.white)
            .background(Color.accentColor)
            .cornerRadius(10.0)
        }.disabled(selectedEmojis.count == 0)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Delete selected Emoji?"),
                primaryButton: .default(Text("Delete")) {
                    withAnimation (.easeInOut) {
                        for emoji in selectedEmojis {
                            document.deleteEmoji(emoji)
                        }
                        selectedEmojis.removeAll()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    @ViewBuilder
    private func debugger() -> some View {
        VStack {
            HStack {
                Text("emoji count:\(selectedEmojis.count)")
                Text("single emoji:\(singleEmojiText)")
            }
            HStack {
                Text("zoom: \(zoomScale)")
                Text("steady: \(steadyStateZoomScale)")
                Text("gesture: \(gestureZoomScale)")
            }
            HStack {
                VStack {
                    Text("pan.w: \(panOffset.width)")
                    Text("pan.h: \(panOffset.height)")
                }
                VStack {
                    Text("steady.w: \(steadyStatePanOffset.width)")
                    Text("steady.h: \(steadyStatePanOffset.height)")
                }
                VStack {
                    Text("gesture.w: \(gesturePanOffset.width)")
                    Text("gesture.h: \(gesturePanOffset.height)")
                }
                VStack {
                    Text("emoji.w: \(gesturePanOffsetEmoji.width)")
                    Text("emoji.h: \(gesturePanOffsetEmoji.height)")
                }
            }
        }
    }
    
    
    // MARK: - Select Emoji
    
    @State private var selectedEmojis: Set<EmojiArt.Emoji> = []
    
    private func tapToSelect(emoji: EmojiArt.Emoji) -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                self.selectedEmojis.toggleMatching(emoji)
            }
    }
    
    private func tapToDeselect() -> some Gesture {
        TapGesture(count: 1)
            .onEnded {
                self.selectedEmojis.removeAll()
            }
    }
    
    
    // MARK: - Zoom Gesture
    
    @State private var steadyStateZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScale: CGFloat = 1.0
    @GestureState private var gestureZoomScaleEmoji: CGFloat = 1.0
    
    private var zoomScale: CGFloat {
        steadyStateZoomScale * gestureZoomScale
    }
    
    private func zoomGesture() -> some Gesture {
        if selectedEmojis.isEmpty {
            return MagnificationGesture()
                .updating($gestureZoomScale) { latestGestureScale, gestureZoomScale, transaction in
                    gestureZoomScale = latestGestureScale
                }
                .onEnded { finalGestureScale in
                    self.steadyStateZoomScale *= finalGestureScale
                }
        } else {
            return MagnificationGesture()
                .updating($gestureZoomScaleEmoji) { latestGestureScale, gestureZoomScaleEmoji, transaction in
                    gestureZoomScaleEmoji = latestGestureScale
                }
                .onEnded { finalGestureScale in
                    for emoji in selectedEmojis {
                        document.scaleEmoji(emoji, by: finalGestureScale)
                    }
                }
        }
    }
    
    
    // MARK: - Pan Gesture (Canvas)
    
    @State private var steadyStatePanOffset: CGSize = .zero
    @GestureState private var gesturePanOffset: CGSize = .zero
    
    private var panOffset: CGSize {
        return (steadyStatePanOffset + gesturePanOffset) * zoomScale
    }
    
    private func panGesture() -> some Gesture {
        DragGesture()
            .updating($gesturePanOffset) { latestDragGestureValue, gesturePanOffset, transaction in
                gesturePanOffset = latestDragGestureValue.translation / self.zoomScale
            }
            .onEnded { finalDragGestureValue in
                self.steadyStatePanOffset = self.steadyStatePanOffset + (finalDragGestureValue.translation / self.zoomScale)
            }
    }
    
    
    // MARK: - Pan Gesture (Emoji)
    
    @GestureState private var gesturePanOffsetEmoji: CGSize = .zero
    
    private func panEmojiGesture(emoji: EmojiArt.Emoji) -> some Gesture {
        DragGesture()
            .onChanged() { _ in
                singleEmoji = selectedEmojis.contains(matching: emoji) ? nil : emoji
            }
            .updating($gesturePanOffsetEmoji) { latestDragGestureValue, gesturePanOffsetEmoji, transaction in
                if selectedEmojis.contains(matching: emoji) {
                    gesturePanOffsetEmoji = latestDragGestureValue.translation
                } else {
                    gesturePanOffsetEmoji = latestDragGestureValue.translation
                }
            }
            .onEnded { finalDragGestureValue in
                if selectedEmojis.contains(matching: emoji) {
                    for e in selectedEmojis {
                        document.moveEmoji(e, by: finalDragGestureValue.translation / self.zoomScale)
                    }
                } else {
                    document.moveEmoji(emoji, by: finalDragGestureValue.translation / self.zoomScale)
                    singleEmoji = nil
                }
            }
    }

    
    // MARK: - Pan Single Emoji Gesture (Extra Credit)

    @State private var singleEmoji: EmojiArt.Emoji?
    
    private var singleEmojiText: String {
        get {
            if let emoji = singleEmoji {
                return emoji.text
            } else {
                return "nil"
            }
        }
    }
    
    
    // MARK: - Zoom to Fit Gesture (Background)
    
    private func doubleTapToZoom(in size: CGSize) -> some Gesture {
        TapGesture(count: 2)
            .onEnded {
                withAnimation {
                    self.zoomToFit(self.document.backgroundImage, in: size)
                }
            }
    }
    
    private func zoomToFit(_ image: UIImage?, in size: CGSize) {
        if let image = image, image.size.width > 0, image.size.height > 0 {
            let hZoom = (size.width - 32) / image.size.width
            let vZoom = (size.height - 32) / image.size.height
            self.steadyStatePanOffset = .zero
            self.steadyStateZoomScale = min(hZoom, vZoom)
        }
    }
    
    
    // MARK: - Emoji Supporting Funcs
    
    private func scale(for emoji: EmojiArt.Emoji) -> CGFloat {
        if selectedEmojis.contains(matching: emoji){
            return emoji.fontSize * self.zoomScale * self.gestureZoomScaleEmoji
        } else {
            return emoji.fontSize * self.zoomScale
        }
    }
    
    private func position(for emoji: EmojiArt.Emoji, in size: CGSize) -> CGPoint {
        var location = emoji.location
        location = CGPoint(x: location.x * zoomScale, y: location.y * zoomScale)
        location = CGPoint(x: location.x + size.width/2, y: location.y + size.height/2)
        location = CGPoint(x: location.x + panOffset.width, y: location.y + panOffset.height)
        if let e = singleEmoji {
            if e.id == emoji.id {
                location = CGPoint(x: location.x + self.gesturePanOffsetEmoji.width, y: location.y + self.gesturePanOffsetEmoji.height)
            }
        } else {
            if selectedEmojis.contains(matching: emoji) {
                location = CGPoint(x: location.x + self.gesturePanOffsetEmoji.width, y: location.y + self.gesturePanOffsetEmoji.height)
            }
        }
        return location
    }
    
    private func drop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        var found = providers.loadFirstObject(ofType: URL.self) { url in
            self.document.setBackgroundURL(url)
        }
        if !found {
            found = providers.loadObjects(ofType: String.self) { string in
                self.document.addEmoji(string, at: location, size: self.defaultEmojiSize)
            }
        }
        return found
    }
    
    
    // MARK: - Drawing Constants
    private let defaultEmojiSize: CGFloat = 40
}
