//
//  AppTheme.swift
//  Pulse Perks
//

import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.1, green: 0.55, blue: 0.42)

    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.05, green: 0.06, blue: 0.06)
            : Color(red: 0.96, green: 0.97, blue: 0.96)
    }

    static func elevatedBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.white.opacity(0.72)
    }

    static func controlBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color(red: 0.91, green: 0.93, blue: 0.92)
    }

    static func stroke(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.06)
    }

    static func heroStart(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.07, green: 0.16, blue: 0.14)
            : Color(red: 0.95, green: 0.98, blue: 1.0)
    }

    static func heroEnd(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.11, green: 0.13, blue: 0.20)
            : Color(red: 0.93, green: 0.96, blue: 0.91)
    }

    static func successBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.06, green: 0.18, blue: 0.13)
            : Color(red: 0.9, green: 0.97, blue: 0.94)
    }
}
