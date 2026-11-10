import KugouLyricsCore
import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: OverlayViewModel

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        if model.needsPermission {
            VStack(spacing: 12) {
                Spacer()
                Text("需要辅助功能权限")
                    .font(.system(size: 22, weight: .semibold))
                Text("用于只读获取酷狗歌曲与播放进度")
                    .foregroundStyle(.white.opacity(0.7))
                Button("打开授权设置") { model.openAccessibilitySettings() }
                Spacer()
            }
        } else if let document = model.document,
                  document.lineIndex(at: model.estimate.progress) != nil {
            let lines = document.window(at: model.estimate.progress, count: model.lineCount)
            VStack(spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    LyricWindowLineView(
                        line: line,
                        color: model.colorPreset.swiftUIColor,
                        activeColor: model.colorPreset.activeSwiftUIColor,
                        isPlaying: model.estimate.isPlaying
                    )
                }
            }
        } else {
            VStack(spacing: 8) {
                Spacer()
                Text(model.track?.title ?? "酷狗多行歌词")
                    .font(.system(size: 24, weight: .semibold))
                    .lineLimit(1)
                if let artist = model.track?.artist {
                    Text(artist)
                        .foregroundStyle(.white.opacity(0.65))
                }
                if model.document != nil {
                    Text("前奏")
                        .foregroundStyle(.white.opacity(0.65))
                } else if !model.status.isEmpty {
                    Text(model.status)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
        }
    }

}

private struct LyricConnector: View {
    let start: CGPoint
    let end: CGPoint
    let progress: Double
    let animationValue: Double
    let color: Color
    let isPlaying: Bool

    private var control: CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: min(start.y, end.y) - 15)
    }

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    private func point(at t: CGFloat) -> CGPoint {
        let remaining = 1 - t
        return CGPoint(
            x: remaining * remaining * start.x + 2 * remaining * t * control.x + t * t * end.x,
            y: remaining * remaining * start.y + 2 * remaining * t * control.y + t * t * end.y
        )
    }

    private var currentPoint: CGPoint {
        point(at: clampedProgress)
    }

    private var wavePath: Path {
        var path = Path()
        guard start != end, clampedProgress > 0 else { return path }

        let sampleCount = 40
        var upperEdge: [CGPoint] = []
        var lowerEdge: [CGPoint] = []
        upperEdge.reserveCapacity(sampleCount + 1)
        lowerEdge.reserveCapacity(sampleCount + 1)

        for index in 0...sampleCount {
            let t = clampedProgress * CGFloat(index) / CGFloat(sampleCount)
            let center = point(at: t)
            let remaining = 1 - t
            let derivative = CGPoint(
                x: 2 * remaining * (control.x - start.x) + 2 * t * (end.x - control.x),
                y: 2 * remaining * (control.y - start.y) + 2 * t * (end.y - control.y)
            )
            let length = max(sqrt(derivative.x * derivative.x + derivative.y * derivative.y), 0.001)
            let normal = CGPoint(x: -derivative.y / length, y: derivative.x / length)
            let halfWidth = 0.5 + 2.25 * sin(.pi * t)
            upperEdge.append(CGPoint(x: center.x + normal.x * halfWidth, y: center.y + normal.y * halfWidth))
            lowerEdge.append(CGPoint(x: center.x - normal.x * halfWidth, y: center.y - normal.y * halfWidth))
        }

        path.move(to: upperEdge[0])
        for point in upperEdge.dropFirst() {
            path.addLine(to: point)
        }
        for point in lowerEdge.reversed() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    var body: some View {
        ZStack {
            if start != end {
                wavePath
                    .fill(color.opacity(0.78))
                    .shadow(color: color.opacity(0.35), radius: 2)
                if clampedProgress > 0, clampedProgress < 1 {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .shadow(color: color.opacity(0.4), radius: 2)
                        .position(currentPoint)
                }
            }
        }
        .opacity(isPlaying ? 1 : 0.65)
        .animation(.linear(duration: 0.1), value: animationValue)
        .allowsHitTesting(false)
    }
}

private struct LyricLineActivityIndicator: View {
    let color: Color
    let isPlaying: Bool
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            LyricConnector(
                start: CGPoint(x: 0, y: 3),
                end: CGPoint(x: proxy.size.width, y: 3),
                progress: progress,
                animationValue: progress,
                color: color,
                isPlaying: isPlaying
            )
        }
        .frame(height: 16)
        .offset(y: -9)
        .accessibilityHidden(true)
    }
}

private struct LyricWordFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] { [:] }

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct LyricPhraseConnector: View {
    let frames: [Int: CGRect]
    let phraseRanges: [Range<Int>]
    let position: Double
    let color: Color
    let isPlaying: Bool

    private func bounds(of range: Range<Int>) -> (start: CGFloat, end: CGFloat)? {
        guard !range.isEmpty,
              let first = frames[range.lowerBound],
              let last = frames[range.upperBound - 1] else {
            return nil
        }
        return (first.minX, last.maxX)
    }

    private var segment: (start: CGPoint, end: CGPoint, progress: Double)? {
        guard position >= 0 else { return nil }
        let phraseIndex = Int(floor(position))
        guard phraseRanges.indices.contains(phraseIndex),
              let bounds = bounds(of: phraseRanges[phraseIndex]) else {
            return nil
        }
        return (
            CGPoint(x: bounds.start, y: 3),
            CGPoint(x: bounds.end, y: 3),
            position - Double(phraseIndex)
        )
    }

    var body: some View {
        GeometryReader { _ in
            if let segment {
                LyricConnector(
                    start: segment.start,
                    end: segment.end,
                    progress: segment.progress,
                    animationValue: position,
                    color: color,
                    isPlaying: isPlaying
                )
            }
        }
        .frame(height: 16)
        .offset(y: -9)
        .accessibilityHidden(true)
    }
}

private struct LyricWindowLineView: View {
    let line: LyricWindowLine
    let color: Color
    let activeColor: Color
    let isPlaying: Bool

    var body: some View {
        content
            .font(.system(size: line.isCurrent ? 24 : 18, weight: line.isCurrent ? .semibold : .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        if line.isCurrent, !line.words.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(line.words.enumerated()), id: \.offset) { index, word in
                    Text(word.text)
                        .foregroundStyle(line.highlightedWordRange?.contains(index) == true ? activeColor : activeColor.opacity(0.72))
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: LyricWordFramePreferenceKey.self,
                                    value: [index: proxy.frame(in: .named("current-lyric-words"))]
                                )
                            }
                        }
                }
            }
            .coordinateSpace(name: "current-lyric-words")
            .overlayPreferenceValue(LyricWordFramePreferenceKey.self, alignment: .topLeading) { frames in
                if let position = line.phrasePosition {
                    LyricPhraseConnector(
                        frames: frames,
                        phraseRanges: line.phraseRanges,
                        position: position,
                        color: activeColor,
                        isPlaying: isPlaying
                    )
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(line.text.isEmpty ? " " : line.text)
                .foregroundStyle(line.isCurrent ? activeColor : color.opacity(0.58))
                .overlay(alignment: .topLeading) { lineActivityIndicator }
        }
    }

    @ViewBuilder
    private var lineActivityIndicator: some View {
        if line.isCurrent, line.words.isEmpty, let progress = line.progress, progress < 1 {
            LyricLineActivityIndicator(color: activeColor, isPlaying: isPlaying, progress: progress)
        }
    }
}

private extension LyricsColorPreset {
    var swiftUIColor: Color {
        switch self {
        case .white: .white
        case .yellow: .yellow
        case .cyan: .cyan
        case .orange: .orange
        }
    }

    var activeSwiftUIColor: Color {
        switch self {
        case .white: .orange
        default: swiftUIColor
        }
    }
}
