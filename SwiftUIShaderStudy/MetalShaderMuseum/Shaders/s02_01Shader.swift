import MetalKit

import simd




public final class S02_01Shader: MSMDrawable {
    public let pipelineState: MTLRenderPipelineState
    private var uniformBuffer: MTLBuffer
    var uniforms = ShaderCommonUniform(seed: 42, time: 0.0, vsize: SIMD2<Float>(800, 600), aspect: 800.0/600.0)

  private var _time: Float = 0.0

  // triangle ２つで全面とする
  private var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]
  
    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexCommon")
        descriptor.fragmentFunction = library.makeFunction(name: "shader02_01")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        uniformBuffer = device.makeBuffer(length: MemoryLayout<ShaderCommonUniform>.stride, options: [])!
    }

    public func setParameters(_ parameters: Any) {
        guard let params = parameters as? ShaderCommonUniform else { return }
        uniforms = params
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<ShaderCommonUniform>.stride)
    }

    public func draw(commandEncoder: MTLRenderCommandEncoder) {
//      uniforms.time = _time
//      _time += 1.0
//      setParameters(uniforms)
//      print("time: \(_time)")
    
        commandEncoder.setRenderPipelineState(pipelineState)
//        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
//      commandEncoder.setVertexBytes(uniformBuffer,
//                                   length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
//                                   index: 0)

      
        // 頂点・描画処理をここに
    }
}



public final class S02_02Shader: MSMDrawable {
    public let pipelineState: MTLRenderPipelineState
    private var uniformBuffer: MTLBuffer
    var uniforms = ShaderCommonUniform(seed: 42, time: 0.0, vsize: SIMD2<Float>(800, 600), aspect: 800.0/600.0)

  private var _time: Float = 0.0

  // triangle ２つで全面とする
  private var triangleVertices: [SIMD4<Float>] = [
    SIMD4<Float>(-1, -1, 0, 1),
    SIMD4<Float>(1.0, -1.0, 0, 1),
    SIMD4<Float>(-1.0, 1.0, 0, 1),
    SIMD4<Float>(1.0, 1.0, 0, 1),
  ]
  
    public init(device: MTLDevice, library: MTLLibrary) throws {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexCommon")
        descriptor.fragmentFunction = library.makeFunction(name: "shader02_02")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        uniformBuffer = device.makeBuffer(length: MemoryLayout<ShaderCommonUniform>.stride, options: [])!
    }

    public func setParameters(_ parameters: Any) {
        guard let params = parameters as? ShaderCommonUniform else { return }
        uniforms = params
        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<ShaderCommonUniform>.stride)
    }

    public func draw(commandEncoder: MTLRenderCommandEncoder) {
//      uniforms.time = _time
//      _time += 1.0
//      setParameters(uniforms)
//      print("time: \(_time)")
    
        commandEncoder.setRenderPipelineState(pipelineState)
//        commandEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 1)
//      commandEncoder.setVertexBytes(uniformBuffer,
//                                   length: MemoryLayout<SIMD4<Float>>.stride * triangleVertices.count,
//                                   index: 0)

      
        // 頂点・描画処理をここに
    }
}
