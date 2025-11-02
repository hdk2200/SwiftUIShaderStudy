//

import Foundation
import MetalKit

protocol MTKViewRendererDelegate: AnyObject {
  func renderer(_ renderer: MTKViewDelegate, didUpdateFPS fps: Double)
}
