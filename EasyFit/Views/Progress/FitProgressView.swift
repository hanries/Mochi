import SwiftUI
import SwiftData

// MARK: - Line Graph (shared component used by LogView)

struct LineGraph: View {
    let entries: [BodyWeightEntry]
    let minW: Double
    let maxW: Double

    var body: some View {
        GeometryReader { geo in
            LineGraphCanvas(entries: entries, minW: minW, maxW: maxW, size: geo.size)
        }
    }
}

struct LineGraphCanvas: View {
    let entries: [BodyWeightEntry]
    let minW: Double
    let maxW: Double
    let size: CGSize

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var range: Double { maxW - minW }

    private func xPos(for i: Int) -> CGFloat {
        entries.count < 2 ? w / 2 : CGFloat(i) / CGFloat(entries.count - 1) * w
    }
    private func yPos(for weight: Double) -> CGFloat {
        h - CGFloat((weight - minW) / range) * h
    }
    private var points: [CGPoint] {
        entries.indices.map { CGPoint(x: xPos(for: $0), y: yPos(for: entries[$0].weight)) }
    }
    private var gridLineYs: [CGFloat] {
        (0..<4).map { h * CGFloat($0) / 3 }
    }

    var body: some View {
        ZStack {
            ForEach(gridLineYs.indices, id: \.self) { i in
                Path { p in
                    p.move(to: CGPoint(x: 0, y: gridLineYs[i]))
                    p.addLine(to: CGPoint(x: w, y: gridLineYs[i]))
                }
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            }
            if points.count > 1 {
                Path { p in
                    p.move(to: CGPoint(x: points[0].x, y: h))
                    p.addLine(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: points.last!.x, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color.primary.opacity(0.12), Color.primary.opacity(0.01)],
                    startPoint: .top, endPoint: .bottom
                ))
            }
            if points.count > 1 {
                Path { p in
                    p.move(to: points[0])
                    for pt in points.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            if let last = points.last {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
                    .position(last)
            }
        }
    }
}
