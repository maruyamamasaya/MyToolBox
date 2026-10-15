// Local diagnostic workload only. Not compiled into the monitoring app.
import Foundation
import Metal
let device = MTLCreateSystemDefaultDevice()!
let source = """
#include <metal_stdlib>
using namespace metal;
kernel void exercise(device float *out [[buffer(0)]], uint i [[thread_position_in_grid]]) {
    float x = float(i) * 0.00001f;
    for (uint j = 0; j < 1000; ++j) { x = sin(x) + 0.5f; }
    out[i] = x;
}
"""
let library = try device.makeLibrary(source: source, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "exercise")!)
let queue = device.makeCommandQueue()!
let buffer = device.makeBuffer(length: 262144 * 4, options: .storageModePrivate)!
let end = ProcessInfo.processInfo.systemUptime + 5
while ProcessInfo.processInfo.systemUptime < end {
    autoreleasepool {
        let command = queue.makeCommandBuffer()!
        let encoder = command.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(pipeline); encoder.setBuffer(buffer, offset: 0, index: 0)
        encoder.dispatchThreads(MTLSize(width: 262144, height: 1, depth: 1), threadsPerThreadgroup: MTLSize(width: pipeline.threadExecutionWidth, height: 1, depth: 1))
        encoder.endEncoding(); command.commit(); command.waitUntilCompleted()
    }
}
