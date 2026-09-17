import { useRef, useEffect, useMemo } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import type { RootState } from '@react-three/fiber';

const vertexShader = `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

const fragmentShader = `
  precision highp float;
  
  uniform float uTime;
  uniform vec2 uResolution;
  uniform vec2 uMouse;
  
  varying vec2 vUv;
  
  // Simplex noise
  vec3 mod289(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
  vec2 mod289(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
  vec3 permute(vec3 x) { return mod289(((x*34.0)+1.0)*x); }
  
  float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v -   i + dot(i, C.xx);
    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;
    i = mod289(i);
    vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                           + i.x + vec3(0.0, i1.x, 1.0));
    vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy),
                            dot(x12.zw,x12.zw)), 0.0);
    m = m*m;
    m = m*m;
    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);
    vec3 g;
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
  }
  
  void main() {
    vec2 uv = vUv;
    float t = uTime * 0.15;
    
    // Multiple layered waves
    float wave1 = snoise(uv * 3.0 + t) * 0.5;
    float wave2 = snoise(uv * 5.0 - t * 0.8) * 0.3;
    float wave3 = snoise(uv * 8.0 + t * 1.2) * 0.15;
    float wave4 = snoise(uv * 12.0 - t * 0.5) * 0.05;
    
    float combinedWave = wave1 + wave2 + wave3 + wave4;
    
    // Mouse influence
    float mouseDist = length(uv - uMouse);
    float mouseInfluence = smoothstep(0.5, 0.0, mouseDist) * 0.3;
    combinedWave += mouseInfluence * sin(t * 3.0);
    
    // Color palette: black base with orange/gold/amber waves
    vec3 black = vec3(0.04, 0.04, 0.04);
    vec3 orange = vec3(1.0, 0.42, 0.1);
    vec3 gold = vec3(1.0, 0.72, 0.0);
    vec3 amber = vec3(1.0, 0.55, 0.0);
    
    // Create gradient based on wave intensity
    float colorMix = smoothstep(-0.3, 0.8, combinedWave);
    float colorMix2 = smoothstep(0.2, 1.0, combinedWave);
    
    vec3 baseColor = mix(black, orange * 0.3, colorMix * 0.5);
    vec3 midColor = mix(baseColor, amber * 0.6, colorMix2 * 0.4);
    vec3 finalColor = mix(midColor, gold * 0.4, smoothstep(0.5, 1.0, combinedWave) * 0.3);
    
    // Add some glow spots
    float glow1 = smoothstep(0.6, 0.0, length(uv - vec2(0.3 + sin(t)*0.2, 0.4 + cos(t*0.7)*0.2)));
    float glow2 = smoothstep(0.5, 0.0, length(uv - vec2(0.7 + cos(t*0.5)*0.15, 0.6 + sin(t*0.9)*0.15)));
    
    finalColor += orange * glow1 * 0.15;
    finalColor += gold * glow2 * 0.1;
    
    // Subtle radial gradient for depth
    float radial = 1.0 - smoothstep(0.0, 1.0, length(uv - 0.5) * 1.2);
    finalColor = mix(finalColor * 0.7, finalColor, radial);
    
    gl_FragColor = vec4(finalColor, 1.0);
  }
`;

function DisplaceWaveMesh() {
  const meshRef = useRef<THREE.Mesh>(null);
  const { viewport } = useThree();
  const mouseRef = useRef({ x: 0.5, y: 0.5 });

  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uResolution: { value: new THREE.Vector2(window.innerWidth, window.innerHeight) },
      uMouse: { value: new THREE.Vector2(0.5, 0.5) },
    }),
    []
  );

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      mouseRef.current.x = e.clientX / window.innerWidth;
      mouseRef.current.y = 1.0 - e.clientY / window.innerHeight;
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  useFrame((state: RootState) => {
    if (meshRef.current) {
      const material = meshRef.current.material as THREE.ShaderMaterial;
      material.uniforms.uTime.value = state.clock.elapsedTime;
      material.uniforms.uMouse.value.x += (mouseRef.current.x - material.uniforms.uMouse.value.x) * 0.05;
      material.uniforms.uMouse.value.y += (mouseRef.current.y - material.uniforms.uMouse.value.y) * 0.05;
    }
  });

  return (
    <mesh ref={meshRef} scale={[viewport.width, viewport.height, 1]}>
      <planeGeometry args={[1, 1, 1, 1]} />
      <shaderMaterial
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
      />
    </mesh>
  );
}

export default function HeroBackground() {
  return (
    <div className="absolute inset-0 z-0">
      <Canvas
        camera={{ position: [0, 0, 1], fov: 75 }}
        dpr={[1, 1.5]}
        gl={{ antialias: false, alpha: false }}
        style={{ width: '100%', height: '100%' }}
      >
        <DisplaceWaveMesh />
      </Canvas>
    </div>
  );
}
