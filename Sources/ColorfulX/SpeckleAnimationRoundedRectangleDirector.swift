//
//  SpeckleAnimationRoundedRectangleDirector.swift
//
//
//  Created by GitHub Copilot on 2025/10/12.
//

import CoreGraphics
import Foundation

open class SpeckleAnimationRoundedRectangleDirector: SpeckleAnimationDirector {
    public enum Direction {
        case clockwise
        case counterClockwise

        var sign: Double { self == .clockwise ? 1 : -1 }
    }

    public var direction: Direction {
        get { directionValue }
        set {
            guard newValue != directionValue else { return }
            directionValue = newValue
            view?.renderInputWasModified = true
        }
    }

    public var inset: Double {
        get { insetValue }
        set {
            assert(newValue <= 1, "Inset must be less than or equal to 1; use negative values to extend outside the unit square.")
            let clamped = Self.clampInset(newValue)
            guard clamped != insetValue else { return }
            insetValue = clamped
            distributionDirty = true
            pathNeedsUpdate = true
            needsPositionRefresh = true
            view?.renderInputWasModified = true
        }
    }

    public var cornerRadius: Double {
        get { cornerRadiusValue }
        set {
            let clamped = Self.clampRadius(newValue)
            guard clamped != cornerRadiusValue else { return }
            cornerRadiusValue = clamped
            pathNeedsUpdate = true
            needsPositionRefresh = true
            view?.renderInputWasModified = true
        }
    }

    public var movementRate: Double {
        get { movementRateValue }
        set {
            let clamped = max(0, newValue)
            guard clamped != movementRateValue else { return }
            movementRateValue = clamped
            view?.renderInputWasModified = true
        }
    }

    public var positionResponseRate: Double {
        get { positionResponseRateValue }
        set {
            let clamped = max(0, newValue)
            guard clamped != positionResponseRateValue else { return }
            positionResponseRateValue = clamped
            view?.renderInputWasModified = true
        }
    }

    private var directionValue: Direction
    private var insetValue: Double
    private var cornerRadiusValue: Double
    private var movementRateValue: Double
    private var positionResponseRateValue: Double

    private var progressState: [Double]
    private var distributionDirty: Bool
    private var needsPositionRefresh: Bool
    private var pathCache: Path
    private var pathNeedsUpdate: Bool
    private var distributionIndices: [Int]

    private static let numericEpsilon: Double = 1e-6

    public init(
        inset: Double = 0.1,
        cornerRadius: Double = 0.18,
        direction: Direction = .clockwise,
        movementRate: Double = 0.25,
        positionResponseRate: Double = 0.5
    ) {
        precondition(inset <= 1, "Inset must be less than or equal to 1; use negative values to extend outside the unit square.")
        directionValue = direction
        insetValue = Self.clampInset(inset)
        cornerRadiusValue = Self.clampRadius(cornerRadius)
        movementRateValue = max(0, movementRate)
        positionResponseRateValue = max(0, positionResponseRate)
        progressState = Array(repeating: 0, count: Uniforms.COLOR_SLOT)
        distributionDirty = true
        needsPositionRefresh = true
        distributionIndices = []
        pathCache = .empty
        pathNeedsUpdate = true
        super.init()
    }

    override open func attach(to view: AnimatedMulticolorGradientView) {
        super.attach(to: view)
    }

    override open func detach() {
        super.detach()
    }

    override open func initialize() {
        if let view {
            ensureProgressCapacity(view.speckles.count)
            refreshDistribution(for: view, force: true)
        }
        super.initialize()
        needsPositionRefresh = false
    }

    override open func update(deltaTime: Double) {
        guard let view else {
            super.update(deltaTime: deltaTime)
            return
        }
        ensureProgressCapacity(view.speckles.count)
        refreshDistribution(for: view)
        advanceProgress(for: view, deltaTime: deltaTime)
        super.update(deltaTime: deltaTime)
        needsPositionRefresh = false
    }

    override open func initializeSpeckle(
        _ speckle: inout AnimatedMulticolorGradientView.Speckle,
        index: Int
    ) {
        super.initializeSpeckle(&speckle, index: index)
        guard index < progressState.count else { return }
        let location = samplePoint(at: progressState[index])
        speckle.position.setCurrent(.init(x: location.x, y: location.y))
        speckle.position.setTarget(.init(x: location.x, y: location.y))
    }

    override open func updateSpeckle(
        _ speckle: inout AnimatedMulticolorGradientView.Speckle,
        index: Int,
        deltaTime: Double
    ) {
        super.updateSpeckle(&speckle, index: index, deltaTime: deltaTime)
        guard let view, index < progressState.count else { return }
        let location = samplePoint(at: progressState[index])
        let targetX = location.x
        let targetY = location.y

        if needsPositionRefresh {
            speckle.position.setCurrent(.init(x: targetX, y: targetY))
            speckle.position.setTarget(.init(x: targetX, y: targetY))
            view.renderInputWasModified = true
            return
        }

        let previousTargetX = speckle.position.x.context.targetPos
        let previousTargetY = speckle.position.y.context.targetPos
        if abs(previousTargetX - targetX) > Self.numericEpsilon
            || abs(previousTargetY - targetY) > Self.numericEpsilon
        {
            speckle.position.setTarget(.init(x: targetX, y: targetY))
            view.renderInputWasModified = true
        }

        let moveDelta = deltaTime * view.speed * positionResponseRateValue
        if moveDelta > 0 {
            speckle.position.update(withDeltaTime: moveDelta)
            view.renderInputWasModified = true
        }
    }
}

private extension SpeckleAnimationRoundedRectangleDirector {
    typealias PathPoint = (x: Double, y: Double)

    struct Path {
        let segments: [Segment]
        let totalLength: Double

        static let empty = Path(segments: [], totalLength: 1)
    }

    struct Segment {
        enum Kind {
            case line(start: PathPoint, end: PathPoint)
            case arc(center: PathPoint, radius: Double, startAngle: Double, endAngle: Double)
        }

        let kind: Kind
        let length: Double

        var endPoint: PathPoint {
            switch kind {
            case let .line(_, end):
                end
            case let .arc(center, radius, _, endAngle):
                Segment.pointOnArc(center: center, radius: radius, angle: endAngle)
            }
        }

        func point(at ratio: Double) -> PathPoint {
            let clamped = SpeckleAnimationRoundedRectangleDirector.clamp01(ratio)
            switch kind {
            case let .line(start, end):
                return (
                    x: start.x + (end.x - start.x) * clamped,
                    y: start.y + (end.y - start.y) * clamped
                )
            case let .arc(center, radius, startAngle, endAngle):
                let angle = startAngle + (endAngle - startAngle) * clamped
                return Segment.pointOnArc(center: center, radius: radius, angle: angle)
            }
        }

        static func line(from start: PathPoint, to end: PathPoint) -> Segment? {
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > SpeckleAnimationRoundedRectangleDirector.numericEpsilon else { return nil }
            return Segment(kind: .line(start: start, end: end), length: length)
        }

        static func arc(
            center: PathPoint,
            radius: Double,
            startAngle: Double,
            endAngle: Double
        ) -> Segment? {
            let delta = endAngle - startAngle
            guard radius > SpeckleAnimationRoundedRectangleDirector.numericEpsilon,
                  delta > SpeckleAnimationRoundedRectangleDirector.numericEpsilon
            else { return nil }
            return Segment(kind: .arc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle), length: radius * delta)
        }

        private static func pointOnArc(center: PathPoint, radius: Double, angle: Double) -> PathPoint {
            (
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
        }
    }

    static func clampInset(_ value: Double) -> Double {
        if value >= 0 {
            return clamp(value, lower: 0, upper: 1)
        }
        return value
    }

    static func clampRadius(_ value: Double) -> Double { max(0, min(value, 0.5)) }

    static func clamp01(_ value: Double) -> Double { clamp(value, lower: 0, upper: 1) }

    static func clamp(_ value: Double, lower: Double, upper: Double) -> Double { min(max(value, lower), upper) }

    func ensureProgressCapacity(_ count: Int) {
        guard count > progressState.count else { return }
        progressState.append(contentsOf: Array(repeating: 0, count: count - progressState.count))
    }

    func refreshDistribution(for view: AnimatedMulticolorGradientView, force: Bool = false) {
        if force { distributionDirty = true }
        ensurePath()

        let enabledIndices = view.speckles.enumerated().compactMap { $0.element.enabled ? $0.offset : nil }
        let desiredDistribution = enabledIndices.isEmpty ? Array(view.speckles.indices) : enabledIndices

        guard distributionDirty || desiredDistribution != distributionIndices else { return }

        distributionIndices = desiredDistribution
        let total = max(distributionIndices.count, 1)
        for (offset, index) in distributionIndices.enumerated() {
            progressState[index] = Double(offset) / Double(total)
        }

        needsPositionRefresh = true
        distributionDirty = false
        view.renderInputWasModified = true
    }

    func advanceProgress(for view: AnimatedMulticolorGradientView, deltaTime: Double) {
        let delta = deltaTime * view.speed * movementRateValue * directionValue.sign
        guard abs(delta) > Self.numericEpsilon else { return }
        if distributionIndices.isEmpty {
            for index in view.speckles.indices {
                progressState[index] = wrap(progressState[index] + delta)
            }
        } else {
            for index in distributionIndices {
                progressState[index] = wrap(progressState[index] + delta)
            }
        }
    }

    func samplePoint(at progress: Double) -> PathPoint {
        ensurePath()
        guard !pathCache.segments.isEmpty else { return (x: 0.5, y: 0.5) }

        let totalLength = pathCache.totalLength
        var remaining = wrap(progress) * totalLength

        for segment in pathCache.segments {
            guard segment.length > Self.numericEpsilon else { continue }
            if remaining <= segment.length {
                let ratio = segment.length <= Self.numericEpsilon ? 0 : remaining / segment.length
                return segment.point(at: ratio)
            }
            remaining -= segment.length
        }

        return pathCache.segments.last?.endPoint ?? (x: 0.5, y: 0.5)
    }

    func ensurePath() {
        guard pathNeedsUpdate else { return }
        pathCache = buildPath()
        pathNeedsUpdate = false
    }

    func buildPath() -> Path {
        let inset = insetValue
        let left = inset
        let right = 1 - inset
        let top = inset
        let bottom = 1 - inset

        let width = max(right - left, 0)
        let height = max(bottom - top, 0)
        guard width > Self.numericEpsilon, height > Self.numericEpsilon else { return .empty }

        let radiusLimit = min(width, height) / 2
        let radius = min(max(cornerRadiusValue, 0), radiusLimit)

        var segments: [Segment] = []

        if radius <= Self.numericEpsilon {
            let topLeft: PathPoint = (x: left, y: top)
            let topRight: PathPoint = (x: right, y: top)
            let bottomRight: PathPoint = (x: right, y: bottom)
            let bottomLeft: PathPoint = (x: left, y: bottom)

            if let line = Segment.line(from: topLeft, to: topRight) { segments.append(line) }
            if let line = Segment.line(from: topRight, to: bottomRight) { segments.append(line) }
            if let line = Segment.line(from: bottomRight, to: bottomLeft) { segments.append(line) }
            if let line = Segment.line(from: bottomLeft, to: topLeft) { segments.append(line) }
        } else {
            let topStart: PathPoint = (x: left + radius, y: top)
            let topEnd: PathPoint = (x: right - radius, y: top)
            let rightStart: PathPoint = (x: right, y: top + radius)
            let rightEnd: PathPoint = (x: right, y: bottom - radius)
            let bottomStart: PathPoint = (x: right - radius, y: bottom)
            let bottomEnd: PathPoint = (x: left + radius, y: bottom)
            let leftStart: PathPoint = (x: left, y: bottom - radius)
            let leftEnd: PathPoint = (x: left, y: top + radius)

            if let line = Segment.line(from: topStart, to: topEnd) { segments.append(line) }
            if let arc = Segment.arc(
                center: (x: right - radius, y: top + radius),
                radius: radius,
                startAngle: 1.5 * .pi,
                endAngle: 2 * .pi
            ) { segments.append(arc) }
            if let line = Segment.line(from: rightStart, to: rightEnd) { segments.append(line) }
            if let arc = Segment.arc(
                center: (x: right - radius, y: bottom - radius),
                radius: radius,
                startAngle: 0,
                endAngle: 0.5 * .pi
            ) { segments.append(arc) }
            if let line = Segment.line(from: bottomStart, to: bottomEnd) { segments.append(line) }
            if let arc = Segment.arc(
                center: (x: left + radius, y: bottom - radius),
                radius: radius,
                startAngle: 0.5 * .pi,
                endAngle: .pi
            ) { segments.append(arc) }
            if let line = Segment.line(from: leftStart, to: leftEnd) { segments.append(line) }
            if let arc = Segment.arc(
                center: (x: left + radius, y: top + radius),
                radius: radius,
                startAngle: .pi,
                endAngle: 1.5 * .pi
            ) { segments.append(arc) }
        }

        let total = segments.reduce(0) { $0 + $1.length }
        return Path(segments: segments, totalLength: max(total, Self.numericEpsilon))
    }

    func wrap(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 1)
        if result < 0 { result += 1 }
        return result
    }
}
