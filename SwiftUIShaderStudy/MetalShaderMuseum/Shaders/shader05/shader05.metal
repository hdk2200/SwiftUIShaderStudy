#include <metal_stdlib>
#include "../../../MetalCommon/ShaderCommonUniform.h"
#include "../../../MetalCommon/shadersample_internal.h"

using namespace metal;

// Ray Marching Constants
constant int MAX_STEPS = 100;
constant float MAX_DIST = 100.0;
constant float SURF_DIST = 0.001;

// Helper Functions
static float3 rotate(float3 p, float3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return p * c + cross(axis, p) * s + axis * dot(axis, p) * oc;
}

static float3 palette(float t) {
    float3 a = float3(0.5, 0.5, 0.5);
    float3 b = float3(0.5, 0.5, 0.5);
    float3 c = float3(1.0, 1.0, 1.0);
    float3 d = float3(0.263, 0.416, 0.557);
    // float3 d = float3(0.0, 0.0, 0.0); // Grayscale
    return a + b * cos(6.28318 * (c * t + d));
}

// SDF Functions
static float sdPlane(float3 p, float h) {
    return p.y - h;
}

static float sdSphere(float3 p, float s) {
    return length(p) - s;
}

static float sdBox(float3 p, float3 b) {
    float3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

static float sdOctahedron(float3 p, float s) {
    p = abs(p);
    return (p.x + p.y + p.z - s) * 0.57735027;
}

static float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Helper to get distance to all objects (excluding plane)
static float getObjectsDist(float3 p, float time) {
    float objectsDist = 1000.0; // Initialize with far distance
    
    // Cycle: Increase number of spheres over time
    // 0 -> 5 spheres -> 0
    float cycle = smoothstep(0.0, 1.0, sin(time * 0.2) * 0.5 + 0.5); 
//    float activeSpheres = 2.0 + cycle * 3.0; // 2 to 5 spheres
    float activeSpheres = 5.0; // 2 to 5 spheres
  
    // Spiral parameters
    float spread = 0.7 + sin(time * 0.3) * 0.3; // Tight to loose spiral (distance varies)
    float yBase = sin(time * 0.4) * 1.2 + 0.2; // Move up and down, mostly above plane
    
    // Loop to create spiral of spheres
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        
        // Smoothly appear/disappear based on active count
        float scale = smoothstep(0.0, 1.0, activeSpheres - fi);
        if (scale <= 0.01) continue;
        
        // Spiral position
        float angle = fi * 0.5 + time * 0.5;
        float radius = 0.0 + fi * spread;
        
        // Individual vertical movement
        float yOffset = sin(fi * 0.8 + time * 1.5) * 0.5;
        
        float3 pos = float3(cos(angle) * radius, yBase + yOffset, sin(angle) * radius);
        
        float size = 0.4 * scale; // Scale size for smooth appearance
        
        float dist = sdSphere(p - pos, size);
        
        // Smooth union of all spheres
        objectsDist = smin(objectsDist, dist, 0.5);
    }
    return objectsDist;
}

// Scene Description
static float getDist(float3 p, float time) {
    // Plane
    float planeDist = sdPlane(p, -1.0);
    
    float objectsDist = getObjectsDist(p, time);
    
    // Fuse with plane
    // Increased smoothing for organic fusion when close
    float d = smin(objectsDist, planeDist, 0.8);
    
    return d;
}

// Ray Marching Loop
static float rayMarch(float3 ro, float3 rd, float time) {
    float dO = 0.0;
    
    for(int i = 0; i < MAX_STEPS; i++) {
        float3 p = ro + rd * dO;
        float dS = getDist(p, time);
        dO += dS;
        if(dO > MAX_DIST || abs(dS) < SURF_DIST) break;
    }
    
    return dO;
}

// Normal Calculation
static float3 getNormal(float3 p, float time) {
    float d = getDist(p, time);
    float2 e = float2(0.001, 0);
    
    float3 n = d - float3(
        getDist(p - e.xyy, time),
        getDist(p - e.yxy, time),
        getDist(p - e.yyx, time)
    );
    
    return normalize(n);
}

// Lighting
static float3 getLight(float3 p, float3 rd, float time) {
    float3 lightPos = float3(2, 4, -3);
    
    float3 l = normalize(lightPos - p);
    float3 n = getNormal(p, time);
    
    // Diffuse
    float dif = clamp(dot(n, l), 0.0, 1.0);
    
    // Specular
    float3 r = reflect(-l, n);
    float spec = pow(clamp(dot(r, -rd), 0.0, 1.0), 32.0);
    
    // Shadow
    float d = rayMarch(p + n * SURF_DIST * 2.0, l, time);
    if(d < length(lightPos - p)) dif *= 0.1;
    
    // Color
    // Use position to vary color
    float3 objectColor = palette(length(p) * 0.2 + time * 0.1);
    float3 planeColor = float3(0.5, 0.5, 0.5); // Gray plane
    
    // Calculate mix factor based on distance to objects vs plane
    float dPlane = sdPlane(p, -1.0);
    float dObjects = getObjectsDist(p, time);
    float k = 0.8; // Same smoothing factor as in getDist
    float h = clamp(0.5 + 0.5 * (dPlane - dObjects) / k, 0.0, 1.0);
    
    float3 col = mix(planeColor, objectColor, h);
    
    // Combine lighting
    float3 amb = float3(0.1);
    col = col * (dif + amb) + float3(spec);
    
    return col;
}

fragment float4 shader05Fragment(VertexOut data [[stage_in]], constant ShaderCommonUniform *uniform [[buffer(0)]]) {
    float2 uv = (data.position.xy * 2.0 - data.vsize) / min(data.vsize.x, data.vsize.y);
    uv.y = -uv.y; // Flip Y to make +Y up
    
    // Interaction Parameters (similar to Shader04 and fragment_primitives_smin logic)
    float zoom = clamp(uniform->scale, 0.1, 5.0);
    float2 rot = uniform->drag / min(data.vsize.x, data.vsize.y) * 5.0;
    float roll = uniform->rotation;
    
    // Camera Setup
    // Start further back to see the plane
    float3 ro = float3(0, 2, -5.0 / zoom); 
    
    // Rotate camera based on drag
    ro = rotate(ro, float3(1, 0, 0), -rot.y);
    ro = rotate(ro, float3(0, 1, 0), -rot.x);
    
    float3 rd = normalize(float3(uv.x, uv.y - 0.6, 1.5)); // Look down more to move scene up
    
    // Apply camera rotation to ray direction
    rd = rotate(rd, float3(0, 0, 1), -roll);
    rd = rotate(rd, float3(1, 0, 0), -rot.y);
    rd = rotate(rd, float3(0, 1, 0), -rot.x);
    
    float d = rayMarch(ro, rd, uniform->time);
    
    float3 col = float3(0.0);
    
    if(d < MAX_DIST) {
        float3 p = ro + rd * d;
        col = getLight(p, rd, uniform->time);
        
        // Fog
        col = mix(col, float3(0.05, 0.05, 0.1), 1.0 - exp(-0.05 * d));
    } else {
        // Background
        col = float3(0.1, 0.1, 0.1);
    }

    // Gamma correction
    col = pow(col, float3(0.4545));

    return float4(col, 1.0);
}
