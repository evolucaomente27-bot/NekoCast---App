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
import { Flame, Sparkles } from 'lucide-react';

export const VerticalHookScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Hook text spring
  const hookSpring = spring({
    frame,
    fps,
    config: { damping: 12, stiffness: 120 },
  });
  const hookScale = interpolate(hookSpring, [0, 1], [0.6, 1]);
  const hookOpacity = interpolate(frame, [0, 8], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Logo spring
  const logoSpring = spring({
    frame: frame - 20,
    fps,
    config: { damping: 12, stiffness: 110 },
  });
  const logoScale = interpolate(logoSpring, [0, 1], [0.3, 1]);
  const logoRotate = interpolate(logoSpring, [0, 1], [-20, 0]);

  // Brand text spring
  const brandSpring = spring({
    frame: frame - 35,
    fps,
    config: { damping: 14, stiffness: 130 },
  });
  const brandY = interpolate(brandSpring, [0, 1], [40, 0]);

  // Exit transition
  const exitProgress = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill style={{ opacity: exitProgress }}>
      <Background glowIntensity={1.6} />

      {/* Center Aura */}
      <div
        style={{
          position: 'absolute',
          top: '48%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '700px',
          height: '700px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(245, 163, 79, 0.45) 0%, rgba(230, 123, 45, 0.15) 55%, transparent 75%)',
          filter: 'blur(50px)',
          pointerEvents: 'none',
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
          padding: '60px 40px',
          zIndex: 10,
          textAlign: 'center',
        }}
      >
        {/* Top Attention Hook Badge */}
        <div
          style={{
            transform: `scale(${hookScale})`,
            opacity: hookOpacity,
            display: 'inline-flex',
            alignItems: 'center',
            gap: '10px',
            backgroundColor: 'rgba(230, 123, 45, 0.25)',
            border: '2px solid rgba(245, 163, 79, 0.6)',
            padding: '12px 28px',
            borderRadius: '30px',
            color: '#FFE3AF',
            fontSize: '24px',
            fontWeight: 800,
            boxShadow: '0 8px 30px rgba(230, 123, 45, 0.4)',
            marginBottom: '40px',
          }}
        >
          <Sparkles size={26} color="#FFC36B" />
          <span>O APP DEFINITIVO DE ANIMES</span>
        </div>

        {/* Hook Question */}
        <h2
          style={{
            transform: `scale(${hookScale})`,
            opacity: hookOpacity,
            fontSize: '52px',
            fontWeight: 900,
            color: '#FFF8F1',
            lineHeight: 1.2,
            margin: '0 0 40px 0',
            letterSpacing: '-1px',
            textShadow: '0 4px 20px rgba(0,0,0,0.8)',
          }}
        >
          Cansado de apps com{' '}
          <span style={{ color: '#FF5F56' }}>anúncios infinitos</span> e travamentos?
        </h2>

        {/* Logo Reveal */}
        <div
          style={{
            transform: `scale(${logoScale}) rotate(${logoRotate}deg)`,
            position: 'relative',
            margin: '20px 0',
          }}
        >
          <div
            style={{
              width: '210px',
              height: '210px',
              borderRadius: '50px',
              background: 'linear-gradient(145deg, #2D1B11 0%, #150D09 100%)',
              border: '3px solid rgba(245, 163, 79, 0.8)',
              boxShadow: '0 30px 70px rgba(0,0,0,0.9), 0 0 65px rgba(230, 123, 45, 0.6)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '20px',
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

          <div
            style={{
              position: 'absolute',
              bottom: '-14px',
              right: '-14px',
              backgroundColor: '#E67B2D',
              color: '#FFF',
              padding: '6px 16px',
              borderRadius: '20px',
              fontSize: '15px',
              fontWeight: 800,
              boxShadow: '0 6px 20px rgba(230, 123, 45, 0.8)',
              border: '2px solid #FFE3AF',
              display: 'flex',
              alignItems: 'center',
              gap: '6px',
            }}
          >
            <Flame size={18} color="#FFF" fill="#FFF" /> NOVO
          </div>
        </div>

        {/* Title */}
        <div
          style={{
            transform: `translateY(${brandY}px)`,
            opacity: interpolate(frame - 35, [0, 8], [0, 1], {
              extrapolateLeft: 'clamp',
              extrapolateRight: 'clamp',
            }),
            marginTop: '30px',
          }}
        >
          <h1
            style={{
              fontSize: '80px',
              fontWeight: 900,
              margin: 0,
              letterSpacing: '-2px',
              background: 'linear-gradient(180deg, #FFFFFF 0%, #FFE3AF 40%, #E67B2D 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              textShadow: '0 10px 45px rgba(230, 123, 45, 0.5)',
            }}
          >
            NekoCast
          </h1>
          <p
            style={{
              fontSize: '30px',
              color: '#FFC36B',
              fontWeight: 700,
              margin: '12px 0 0 0',
              textShadow: '0 2px 15px rgba(0,0,0,0.8)',
            }}
          >
            Animes & Mangás sem limites!
          </p>
        </div>
      </div>
    </AbsoluteFill>
  );
};
