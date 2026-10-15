import Foundation
public enum AudioSignal {
    /// A 440 Hz tone with short fades; sequence 2 means left, right, then both.
    public static func stereo(time: Double, sequence: Int, volume: Double) -> (Float, Float) {
        let segment = sequence == 2 ? Int(time / 0.8) : sequence
        let local = sequence == 2 ? time.truncatingRemainder(dividingBy: 0.8) : time
        let envelope = max(0, min(1, local / 0.015, (0.55 - local) / 0.025))
        let value = Float(sin(2 * .pi * 440 * time) * min(0.6, max(0, volume)) * envelope)
        return (segment == 1 ? 0 : value, segment == 0 ? 0 : value)
    }
    public static func levels(_ samples: UnsafeBufferPointer<Float>) -> (rms: Float, peak: Float) {
        guard !samples.isEmpty else { return (0, 0) }
        var sum: Double = 0; var peak: Float = 0
        for value in samples { sum += Double(value) * Double(value); peak = max(peak, abs(value)) }
        return (Float(sqrt(sum / Double(samples.count))), peak)
    }
}
