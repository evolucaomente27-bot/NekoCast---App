import React from 'react';
import { interpolate, useCurrentFrame, useVideoConfig } from 'remotion';
import { AppColors } from '../theme/colors';

interface BackgroundProps {
  glowIntensity?: number;
  showGrid?: boolean;
}

export const Background: React.FC<BackgroundProps> = ({
  glowIntensity = 1,
  showGrid = true,
}) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Floating ambient light positions
  const orb1X = 20 + Math.sin(frame / 40) * 10;
  const orb1Y = 30 + Math.cos(frame / 50) * 12;
  const orb2X = 75 + Math.cos(frame / 45) * 12;
  const orb2Y = 65 + Math.sin(frame / 35) * 10;
  const orb3X = 50 + Math.sin(frame / 60) * 15;
  const orb3Y = 40 + Math.cos(frame / 40) * 8;

  // Pulse effect
  const pulse = 1 + Math.sin(frame / 20) * 0.15 * glowIntensity;

  // Particle positions
  const particles = React.useMemo(() => {
    return Array.from({ length: 28 }).map((_, i) => {
      const baseX = (i * 37) % 100;
      const baseY = (i * 53) % 100;
      const speed = 0.2 + (i % 5) * 0.15;
      const size = 2 + (i % 4) * 2;
      const opacity = 0.2 + (i % 6) * 0.1;
      return { baseX, baseY, speed, size, opacity };
    });
  }, []);

  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        backgroundColor: AppColors.background,
        overflow: 'hidden',
        fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
      }}
    >
      {/* Background Gradient Mesh */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `
            radial-gradient(circle at ${orb1X}% ${orb1Y}%, rgba(245, 163, 79, ${0.22 * glowIntensity * pulse}) 0%, transparent 45%),
            radial-gradient(circle at ${orb2X}% ${orb2Y}%, rgba(230, 123, 45, ${0.18 * glowIntensity * pulse}) 0%, transparent 50%),
            radial-gradient(circle at ${orb3X}% ${orb3Y}%, rgba(139, 92, 56, ${0.25 * glowIntensity}) 0%, transparent 60%),
            linear-gradient(180deg, #180F0A 0%, #0D0705 100%)
          `,
        }}
      />

      {/* Cyberpunk/Anime Dot Grid Overlay */}
      {showGrid && (
        <div
          style={{
            position: 'absolute',
            inset: 0,
            backgroundImage: `
              radial-gradient(rgba(245, 163, 79, 0.12) 1px, transparent 1px),
              linear-gradient(to right, rgba(230, 123, 45, 0.03) 1px, transparent 1px),
              linear-gradient(to bottom, rgba(230, 123, 45, 0.03) 1px, transparent 1px)
            `,
            backgroundSize: '36px 36px, 72px 72px, 72px 72px',
            opacity: 0.65,
          }}
        />
      )}

      {/* Floating Sparkles & Dust Particles */}
      {particles.map((p, idx) => {
        const yOffset = (frame * p.speed * 2) % 110;
        const currentY = (p.baseY - yOffset + 110) % 110;
        const currentX = p.baseX + Math.sin((frame + idx * 20) / 30) * 3;
        const flicker = 0.5 + Math.sin((frame + idx * 10) / 12) * 0.5;

        return (
          <div
            key={idx}
            style={{
              position: 'absolute',
              left: `${currentX}%`,
              top: `${currentY}%`,
              width: `${p.size}px`,
              height: `${p.size}px`,
              borderRadius: '50%',
              backgroundColor: AppColors.primaryGlow,
              boxShadow: `0 0 ${p.size * 3}px ${AppColors.primaryLight}`,
              opacity: p.opacity * flicker * glowIntensity,
              pointerEvents: 'none',
            }}
          />
        );
      })}

      {/* Subtle Vignette */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          boxShadow: 'inset 0 0 160px rgba(0, 0, 0, 0.85)',
          pointerEvents: 'none',
        }}
      />
    </div>
  );
};
