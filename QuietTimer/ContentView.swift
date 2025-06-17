//
//  ContentView.swift
//  QuietTimer
//
//  Created by Lyle Klyne on 6/13/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        SwipeableTabView()
            .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
}
