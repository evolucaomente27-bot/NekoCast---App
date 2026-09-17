import React from 'react';
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { Background } from '../components/Background';
import { DeviceMockup } from '../components/DeviceMockup';
import { AppColors } from '../theme/colors';
import { FastForward, Zap, Play, RotateCcw, Volume2, Check } from 'lucide-react';

export const VerticalPlayerScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const titleSpring = spring({
    frame,
    fps,
    config: { damping: 13, stiffness: 120 },
  });

  const isClicked = frame >= 45;
  const buttonSpring = spring({
    frame: frame - 15,
    fps,
    config: { damping: 10, stiffness: 140 },
  });

  const progress = interpolate(frame, [0, durationInFrames], [20, 80], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const exitProgress = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill style={{ opacity: exitProgress }}>
      <Background glowIntensity={1.5} />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '80px 40px 60px 40px',
          zIndex: 10,
        }}
      >
        {/* Top Header */}
        <div
          style={{
            transform: `translateY(${interpolate(titleSpring, [0, 1], [-30, 0])}px)`,
            textAlign: 'center',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              backgroundColor: 'rgba(255, 179, 0, 0.25)',
              border: '1.5px solid rgba(255, 179, 0, 0.7)',
              padding: '8px 22px',
              borderRadius: '24px',
              color: '#FFB300',
              fontSize: '18px',
              fontWeight: 800,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <Zap size={20} color="#FFB300" fill="#FFB300" />
            RECURSO REVOLUCIONÁRIO
          </div>

          <h2
            style={{
              fontSize: '52px',
              fontWeight: 900,
              color: '#FFF8F1',
              margin: 0,
              lineHeight: 1.15,
            }}
          >
            AniSkip Integrado:{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #FFB300 0%, #FFC36B 50%, #E67B2D 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              Pule Aberturas
            </span>
          </h2>
        </div>

        {/* Center: Smartphone Mockup with Player */}
        <div style={{ transform: 'scale(1.12)' }}>
          <DeviceMockup type="phone" delay={5} rotation={0}>
            <div
              style={{
                flex: 1,
                backgroundColor: '#090503',
                position: 'relative',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                padding: '24px 16px',
                paddingTop: '40px',
                overflow: 'hidden',
              }}
            >
              {/* Anime scene backdrop */}
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: 'radial-gradient(circle at center, rgba(230,123,45,0.4) 0%, rgba(18,11,8,0.95) 75%)',
                }}
              />

              {/* Top info */}
              <div style={{ zIndex: 10, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div>
                  <div style={{ fontSize: '14px', fontWeight: 800, color: '#FFF' }}>Jujutsu Kaisen — Ep 17</div>
                  <div style={{ fontSize: '11px', color: AppColors.textTertiary }}>Áudio Japonês (Legendas PT-BR)</div>
                </div>
                <div style={{ backgroundColor: 'rgba(230,123,45,0.3)', border: '1px solid #F5A34F', color: '#FFE3AF', padding: '3px 8px', borderRadius: '8px', fontSize: '10px', fontWeight: 800 }}>
                  1080p FHD
                </div>
              </div>

              {/* Center AniSkip Button */}
              <div
                style={{
                  zIndex: 20,
                  alignSelf: 'center',
                  transform: `scale(${buttonSpring * (isClicked ? 0.95 : 1)})`,
                  backgroundColor: isClicked ? 'rgba(76, 175, 80, 0.95)' : 'rgba(245, 163, 79, 0.95)',
                  color: '#120B08',
                  padding: '12px 20px',
                  borderRadius: '30px',
                  border: '2px solid #FFF',
                  boxShadow: isClicked ? '0 0 30px rgba(76,175,80,0.8)' : '0 0 30px rgba(245,163,79,0.8)',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '10px',
                  fontWeight: 800,
                  fontSize: '14px',
                }}
              >
                {isClicked ? <Check size={18} strokeWidth={3} /> : <FastForward size={18} />}
                {isClicked ? '✓ Abertura Pulada!' : 'Pular Abertura (01:30)'}
              </div>

              {/* Bottom timeline */}
              <div style={{ zIndex: 10, display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: '#FFF', fontWeight: 700 }}>
                  <span>{isClicked ? '03:15' : '01:40'}</span>
                  <span>23:45</span>
                </div>
                <div style={{ height: '6px', backgroundColor: 'rgba(255,255,255,0.2)', borderRadius: '3px', overflow: 'hidden' }}>
                  <div style={{ width: `${progress}%`, height: '100%', backgroundColor: AppColors.primary, boxShadow: '0 0 8px rgba(230,123,45,0.8)' }} />
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-around', paddingTop: '8px' }}>
                  <RotateCcw size={16} color="#FFF" />
                  <div style={{ width: '28px', height: '28px', borderRadius: '50%', backgroundColor: AppColors.primary, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <Play size={12} fill="#FFF" color="#FFF" />
                  </div>
                  <FastForward size={16} color="#FFF" />
                  <Volume2 size={16} color="#FFF" />
                </div>
              </div>
            </div>
          </DeviceMockup>
        </div>

        {/* Bottom Tag */}
        <div
          style={{
            backgroundColor: 'rgba(38, 23, 17, 0.95)',
            border: '2px solid rgba(255, 179, 0, 0.6)',
            padding: '14px 28px',
            borderRadius: '30px',
            color: '#FFE3AF',
            fontSize: '20px',
            fontWeight: 800,
            boxShadow: '0 8px 30px rgba(0,0,0,0.7)',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
          }}
        >
          <FastForward size={22} color="#FFB300" />
          Economize tempo e assista direto ao anime!
        </div>
      </div>
    </AbsoluteFill>
  );
};
