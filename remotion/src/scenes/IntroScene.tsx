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
import { Sparkles, Play, Tv, Flame, Star, ShieldCheck } from 'lucide-react';

export const IntroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Entrance spring for the main logo
  const logoProgress = spring({
    frame,
    fps,
    config: {
      damping: 12,
      stiffness: 100,
      mass: 1,
    },
  });

  const logoScale = interpolate(logoProgress, [0, 1], [0.3, 1]);
  const logoRotate = interpolate(logoProgress, [0, 1], [-25, 0]);

  // Title spring
  const titleProgress = spring({
    frame: frame - 12,
    fps,
    config: { damping: 14, stiffness: 120 },
  });
  const titleY = interpolate(titleProgress, [0, 1], [40, 0]);
  const titleOpacity = interpolate(frame - 12, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Subtitle spring
  const subProgress = spring({
    frame: frame - 25,
    fps,
    config: { damping: 15, stiffness: 130 },
  });
  const subY = interpolate(subProgress, [0, 1], [30, 0]);
  const subOpacity = interpolate(frame - 25, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Tag pills springs
  const pill1 = spring({ frame: frame - 40, fps, config: { damping: 12 } });
  const pill2 = spring({ frame: frame - 50, fps, config: { damping: 12 } });
  const pill3 = spring({ frame: frame - 60, fps, config: { damping: 12 } });

  // Rotating energy rings
  const ringRotation = (frame * 1.2) % 360;
  const ringPulse = 1 + Math.sin(frame / 15) * 0.08;

  // Scene transition out
  const exitProgress = interpolate(
    frame,
    [durationInFrames - 15, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  const exitScale = interpolate(
    frame,
    [durationInFrames - 15, durationInFrames],
    [1, 1.08],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill
      style={{
        opacity: exitProgress,
        transform: `scale(${exitScale})`,
      }}
    >
      <Background glowIntensity={1.5} />

      {/* Center Aura / Glow Effect */}
      <div
        style={{
          position: 'absolute',
          top: '38%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '650px',
          height: '650px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(245, 163, 79, 0.45) 0%, rgba(230, 123, 45, 0.2) 45%, transparent 70%)',
          filter: 'blur(45px)',
          pointerEvents: 'none',
        }}
      />

      {/* Rotating Cyberpunk Accent Ring */}
      <div
        style={{
          position: 'absolute',
          top: '34%',
          left: '50%',
          transform: `translate(-50%, -50%) rotate(${ringRotation}deg) scale(${ringPulse})`,
          width: '360px',
          height: '360px',
          borderRadius: '50%',
          border: '2px dashed rgba(245, 163, 79, 0.5)',
          boxShadow: '0 0 35px rgba(230, 123, 45, 0.3)',
          pointerEvents: 'none',
        }}
      />

      {/* Main Content Center */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 10,
        }}
      >
        {/* Animated Fox / Neko Logo */}
        <div
          style={{
            transform: `scale(${logoScale}) rotate(${logoRotate}deg)`,
            marginBottom: '24px',
            position: 'relative',
          }}
        >
          <div
            style={{
              width: '180px',
              height: '180px',
              borderRadius: '42px',
              background: 'linear-gradient(145deg, #2D1B11 0%, #150D09 100%)',
              border: '2.5px solid rgba(245, 163, 79, 0.75)',
              boxShadow: '0 25px 60px rgba(0,0,0,0.85), 0 0 55px rgba(230, 123, 45, 0.55)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              overflow: 'hidden',
              padding: '16px',
            }}
          >
            <Img
              src={staticFile('logo.png')}
              style={{
                width: '100%',
                height: '100%',
                objectFit: 'contain',
                filter: 'drop-shadow(0 8px 20px rgba(0,0,0,0.7))',
              }}
            />
          </div>

          {/* Glowing Badge Tag */}
          <div
            style={{
              position: 'absolute',
              bottom: '-12px',
              right: '-12px',
              backgroundColor: '#E67B2D',
              color: '#FFF',
              padding: '5px 14px',
              borderRadius: '24px',
              fontSize: '13px',
              fontWeight: 800,
              letterSpacing: '0.8px',
              boxShadow: '0 6px 20px rgba(230, 123, 45, 0.7)',
              border: '1.5px solid #FFC36B',
              display: 'flex',
              alignItems: 'center',
              gap: '5px',
            }}
          >
            <Flame size={15} color="#FFF" fill="#FFF" /> v1.0.3
          </div>
        </div>

        {/* Title */}
        <div
          style={{
            transform: `translateY(${titleY}px)`,
            opacity: titleOpacity,
            textAlign: 'center',
          }}
        >
          <h1
            style={{
              fontSize: '84px',
              fontWeight: 900,
              margin: 0,
              letterSpacing: '-1.5px',
              background: 'linear-gradient(180deg, #FFFFFF 0%, #FFE3AF 40%, #E67B2D 100%)',
              WebkitBackgroundClip: 'text',
              WebkitTextFillColor: 'transparent',
              textShadow: '0 10px 45px rgba(230, 123, 45, 0.5)',
            }}
          >
            NekoCast
          </h1>
        </div>

        {/* Subtitle */}
        <div
          style={{
            transform: `translateY(${subY}px)`,
            opacity: subOpacity,
            textAlign: 'center',
            marginTop: '12px',
          }}
        >
          <p
            style={{
              fontSize: '28px',
              color: '#FFF8F1',
              fontWeight: 600,
              margin: 0,
              letterSpacing: '0.3px',
              textShadow: '0 2px 10px rgba(0,0,0,0.8)',
            }}
          >
            Sua Central Definitiva de{' '}
            <span
              style={{
                color: '#FFC36B',
                fontWeight: 800,
                textShadow: '0 0 25px rgba(245, 163, 79, 0.6)',
              }}
            >
              Animes & Mangás
            </span>
          </p>
        </div>

        {/* Highlight Feature Pills */}
        <div
          style={{
            display: 'flex',
            gap: '20px',
            marginTop: '42px',
          }}
        >
          {/* Pill 1 */}
          <div
            style={{
              transform: `scale(${pill1})`,
              opacity: interpolate(frame - 40, [0, 8], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              backgroundColor: 'rgba(38, 23, 17, 0.95)',
              backdropFilter: 'blur(16px)',
              border: '1.5px solid rgba(245, 163, 79, 0.5)',
              padding: '12px 24px',
              borderRadius: '35px',
              color: '#FFF8F1',
              fontSize: '17px',
              fontWeight: 700,
              boxShadow: '0 8px 30px rgba(0,0,0,0.5), 0 0 20px rgba(230, 123, 45, 0.25)',
            }}
          >
            <Sparkles size={20} color={AppColors.accent} />
            Streaming & Catálogo Ilimitado
          </div>

          {/* Pill 2 */}
          <div
            style={{
              transform: `scale(${pill2})`,
              opacity: interpolate(frame - 50, [0, 8], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              backgroundColor: 'rgba(38, 23, 17, 0.95)',
              backdropFilter: 'blur(16px)',
              border: '1.5px solid rgba(245, 163, 79, 0.5)',
              padding: '12px 24px',
              borderRadius: '35px',
              color: '#FFF8F1',
              fontSize: '17px',
              fontWeight: 700,
              boxShadow: '0 8px 30px rgba(0,0,0,0.5), 0 0 20px rgba(230, 123, 45, 0.25)',
            }}
          >
            <Tv size={20} color={AppColors.primaryLight} />
            AniSkip (Pular Abertura)
          </div>

          {/* Pill 3 */}
          <div
            style={{
              transform: `scale(${pill3})`,
              opacity: interpolate(frame - 60, [0, 8], [0, 1], {
                extrapolateLeft: 'clamp',
                extrapolateRight: 'clamp',
              }),
              display: 'flex',
              alignItems: 'center',
              gap: '10px',
              backgroundColor: 'rgba(38, 23, 17, 0.95)',
              backdropFilter: 'blur(16px)',
              border: '1.5px solid rgba(76, 175, 80, 0.6)',
              padding: '12px 24px',
              borderRadius: '35px',
              color: '#FFF8F1',
              fontSize: '17px',
              fontWeight: 700,
              boxShadow: '0 8px 30px rgba(0,0,0,0.5), 0 0 20px rgba(76, 175, 80, 0.25)',
            }}
          >
            <Play size={20} color={AppColors.success} fill={AppColors.success} />
            Downloads & Offline
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
