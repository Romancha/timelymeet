//
//  LiquidGlassComponents.swift
//  TimelyMeet
//
//  Liquid Glass Design System Components
//  Following Apple HIG 2025 guidelines
//

import SwiftUI

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    let isProminent: Bool
    let size: ControlSize

    init(isProminent: Bool = false, size: ControlSize = .regular) {
        self.isProminent = isProminent
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                Group {
                    if isProminent {
                        Capsule()
                            .fill(Color.accentColor)
                            .overlay(
                                // Specular highlight
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(Capsule())
                            )
                    } else {
                        Capsule()
                            .fill(.regularMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            )
            .shadow(
                color: isProminent ? Color.accentColor.opacity(0.3) : .black.opacity(0.1),
                radius: isProminent ? 10 : 5,
                y: isProminent ? 5 : 2
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .mini: return 12
        case .small: return 16
        case .regular: return 20
        case .large: return 24
        case .extraLarge: return 28
        @unknown default: return 20
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .mini: return 6
        case .small: return 8
        case .regular: return 10
        case .large: return 12
        case .extraLarge: return 14
        @unknown default: return 10
        }
    }
}

// MARK: - Floating Container

struct FloatingContainer<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let material: Material

    init(
        cornerRadius: CGFloat = 16,
        material: Material = .regularMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay(
                        // Subtle border
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
            .padding(.horizontal, 8)
    }
}

// MARK: - Liquid Glass Card

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let isSelected: Bool
    let cornerRadius: CGFloat

    init(
        isSelected: Bool = false,
        cornerRadius: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Dynamic highlight
                    LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            )
            .overlay(
                // Selection border with animation
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.clear,
                        lineWidth: isSelected ? 2 : 0
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
            )
            .shadow(
                color: isSelected ? Color.accentColor.opacity(0.2) : .black.opacity(0.05),
                radius: isSelected ? 15 : 8,
                y: isSelected ? 8 : 4
            )
    }
}

// MARK: - Status Indicator with Liquid Glass

struct LiquidGlassStatusIndicator: View {
    let color: Color
    let isActive: Bool
    let size: CGFloat

    init(color: Color, isActive: Bool = false, size: CGFloat = 8) {
        self.color = color
        self.isActive = isActive
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.7)],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: color.opacity(0.3), radius: isActive ? 4 : 2, y: 1)
            .scaleEffect(isActive ? 1.2 : 1)
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isActive)
    }
}

// MARK: - Convenience Extensions

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle {
        LiquidGlassButtonStyle()
    }

    static func liquidGlass(isProminent: Bool, size: ControlSize = .regular) -> LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(isProminent: isProminent, size: size)
    }
}

// MARK: - Material Compatibility

extension Material {
    /// Ultra-thin material for floating elements
    static var liquidGlass: Material { .ultraThinMaterial }

    /// Regular material for containers
    static var liquidGlassContainer: Material { .regularMaterial }
}