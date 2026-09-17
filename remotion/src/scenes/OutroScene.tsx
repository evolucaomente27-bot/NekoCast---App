import React from 'react';
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { Background } from '../components/Background';
import { AppColors } from '../theme/colors';
import {
  Github,
  Download,
  Heart,
  Star,
  ShieldCheck,
  Sparkles,
} from 'lucide-react';

export const OutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Entrance spring
  const logoProgress = spring({
    frame,
    fps,
    config: { damping: 12, stiffness: 100 },
  });
  const logoScale = interpolate(logoProgress, [0, 1], [0.4, 1]);

  const titleProgress = spring({
    frame: frame - 15,
    fps,
    config: { damping: 14, stiffness: 120 },
  });
  const titleY = interpolate(titleProgress, [0, 1], [30, 0]);
  const titleOpacity = interpolate(frame - 15, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const ctaProgress = spring({
    frame: frame - 30,
    fps,
    config: { damping: 12, stiffness: 130 },
  });
  const ctaScale = interpolate(ctaProgress, [0, 1], [0.8, 1]);
  const ctaOpacity = interpolate(frame - 30, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Pulse effect
  const pulse = 1 + Math.sin(frame / 18) * 0.04;

  return (
    <AbsoluteFill>
      <Background glowIntensity={1.5} />

      {/* Central Radiance Glow */}
      <div
        style={{
          position: 'absolute',
          top: '40%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '600px',
          height: '600px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(245, 163, 79, 0.4) 0%, rgba(230, 123, 45, 0.15) 50%, transparent 70%)',
          filter: 'blur(45px)',
        }}
      />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10,
          padding: '40px',
        }}
      >
        {/* Logo with Glow Ring */}
        <div
          style={{
            transform: `scale(${logoScale * pulse})`,
            marginBottom: '16px',
            position: 'relative',
          }}
        >
          <div
            style={{
              width: '130px',
              height: '130px',
              borderRadius: '32px',
              background: 'linear-gradient(145deg, #2A1A12 0%, #150D09 100%)',
              border: '2px solid rgba(245, 163, 79, 0.7)',
              boxShadow: '0 20px 40px rgba(0,0,0,0.8), 0 0 50px rgba(230, 123, 45, 0.5)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '12px',
            }}
          >
            <Img
              src={staticFile('logo.png')}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'contain',
              }}
            />
          </div>
        </div>

        {/* Big Headline */}
        <div
          style={{
            transform: `translateY(${titleY}px)`,
            opacity: titleOpacity,
            textAlign: 'center',
          }}
        >
          <h1
            style={{
              fontSize: '64px',
              fontWeight: 900,
              margin: 0,
              letterSpacing: '-1.5px',
              background: 'linear-gradient(180deg, #FFFFFF 0%, #FFE3AF 40%, #E67B2D 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              textShadow: '0 10px 40px rgba(230, 123, 45, 0.45)',
            }}
          >
            Transforme sua Experiência Otaku
          </h1>

          <p
            style={{
              fontSize: '22px',
              color: AppColors.textSecondary,
              marginTop: '12px',
              marginBottom: '0',
            }}
          >
            Animes, Mangás, AniSkip e Downloads Offline em um só lugar.
          </p>
        </div>

        {/* CTA Card */}
        <div
          style={{
            transform: `scale(${ctaScale})`,
            opacity: ctaOpacity,
            marginTop: '32px',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '20px',
          }}
        >
          {/* Main Download CTA Button */}
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '14px',
              background: 'linear-gradient(135deg, #F5A34F 0%, #E67B2D 100%)',
              color: '#120B08',
              padding: '16px 40px',
              borderRadius: '50px',
              fontSize: '22px',
              fontWeight: 900,
              boxShadow: '0 12px 35px rgba(230, 123, 45, 0.6), 0 0 20px rgba(255, 195, 107, 0.4)',
              border: '2px solid #FFE3AF',
              letterSpacing: '0.5px',
            }}
          >
            <Download size={26} color="#120B08" strokeWidth={2.8} />
            Baixe o NekoCast Agora
          </div>

          {/* Secondary GitHub & Info Pills */}
          <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                backgroundColor: 'rgba(36, 23, 18, 0.9)',
                border: '1px solid rgba(245, 163, 79, 0.35)',
                padding: '8px 18px',
                borderRadius: '20px',
                color: AppColors.textPrimary,
                fontSize: '14px',
                fontWeight: 600,
              }}
            >
              <Github size={16} color={AppColors.primaryLight} />
              <span>evolucaomente27-bot/NekoCast---App</span>
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                backgroundColor: 'rgba(36, 23, 18, 0.9)',
                border: '1px solid rgba(76, 175, 80, 0.4)',
                padding: '8px 18px',
                borderRadius: '20px',
                color: AppColors.success,
                fontSize: '14px',
                fontWeight: 700,
              }}
            >
              <ShieldCheck size={16} />
              <span>100% Gratuito & Open Source (MIT)</span>
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
