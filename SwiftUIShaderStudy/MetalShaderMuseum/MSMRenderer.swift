import MetalKit
import Combine

public struct ShaderCommonUniform {
    public var seed: UInt32           // uint32_t
    public var time: Float            // float
    public var vsize: SIMD2<Float>    // vector_float2
    public var aspect: Float          // float
    public var tsize: SIMD2<Float>    // vector_float2 (Texture size)
    public var userpt: SIMD3<Float>   // vector_float3 (user pointer)

    public init(seed: UInt32 = 0,
                time: Float = 0,
                vsize: SIMD2<Float> = .zero,
                aspect: Float = 1.0,
                tsize: SIMD2<Float> = .zero,
                userpt: SIMD3<Float> = .zero) {
        self.seed = seed
        self.time = time
        self.vsize = vsize
        self.aspect = aspect
        self.tsize = tsize
        self.userpt = userpt
    }
}

import MetalKit
import simd
import Combine

public final class MSMRenderer: NSObject, ObservableObject, MTKViewDelegate {

    // MARK: - Metal resources
    public let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    // MARK: - SwiftUI bindings
    @Published public var currentShader: MSMDrawable
    @Published public var frameCount: Int = 0

    // MARK: - Vertex + Uniform
    private var triangleVertices: [SIMD4<Float>] = [
        SIMD4<Float>(-1, -1, 0, 1),
        SIMD4<Float>(1.0, -1.0, 0, 1),
        SIMD4<Float>(-1.0, 1.0, 0, 1),
        SIMD4<Float>(1.0, 1.0, 0, 1),
    ]

    private var viewportSize: CGSize = .zero
    private var startTime: CFTimeInterval = CACurrentMediaTime()
    private var seed: UInt32 = UInt32.random(in: 0...UInt32.max)
    private var tapPoint: CGPoint = .zero
    private var zPoint: Float = 0.0

    public init(device: MTLDevice, shader: MSMDrawable) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.currentShader = shader
    }

    // MARK: - Public updates
    public func updateShaderParameters(_ params: Any) {
        currentShader.setParameters(params)
    }

    public func updateTap(point: CGPoint, z: Float = 0.0) {
        tapPoint = point
        zPoint = z
    }

    // MARK: - MTKViewDelegate

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
    }

    public func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }

        // FPS進行
        frameCount += 1
        let elapsed = Float(CACurrentMediaTime() - startTime)

        // Uniform構築
        let vSize = SIMD2<Float>(Float(viewportSize.width), Float(viewportSize.height))
        let tSize = SIMD2<Float>(0.0, 0.0)
        let pt = SIMD3<Float>(Float(tapPoint.x), Float(tapPoint.y), zPoint)
        var uniforms = ShaderCommonUniform(
            seed: seed,
            time: Float(Float(frameCount) / Float(view.preferredFramesPerSecond)),
            vsize: vSize,
            aspect: Float(viewportSize.width / max(1, viewportSize.height)),
            tsize: tSize,
            userpt: pt
        )

        // コマンドバッファ作成
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        // ビューポート設定
        encoder.setViewport(MTLViewport(originX: 0,
                                        originY: 0,
                                        width: Double(viewportSize.width),
                                        height: Double(viewportSize.height),
                                        znear: 0.0, zfar: 1.0))

        // currentShader に独自の設定をさせる
        currentShader.draw(commandEncoder: encoder)

        // 頂点情報とUniformを設定（全Shader共通）
        encoder.setVertexBytes(triangleVertices,
                               length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
                               index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<ShaderCommonUniform>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ShaderCommonUniform>.stride, index: 0)

        // 描画コマンド
        encoder.drawPrimitives(type: .triangleStrip,
                               vertexStart: 0,
                               vertexCount: triangleVertices.count)

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
