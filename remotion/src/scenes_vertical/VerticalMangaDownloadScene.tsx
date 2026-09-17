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
import {
  BookOpen,
  Download,
  CheckCircle2,
  WifiOff,
  Smartphone,
  Layers,
} from 'lucide-react';

export const VerticalMangaDownloadScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const titleSpring = spring({
    frame,
    fps,
    config: { damping: 13, stiffness: 120 },
  });

  const downloadProgress = Math.min(100, Math.floor(interpolate(frame, [0, 60], [45, 100])));

  const exitProgress = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill style={{ opacity: exitProgress }}>
      <Background glowIntensity={1.3} />

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
              backgroundColor: 'rgba(76, 175, 80, 0.25)',
              border: '1.5px solid rgba(76, 175, 80, 0.7)',
              padding: '8px 22px',
              borderRadius: '24px',
              color: '#A5D6A7',
              fontSize: '18px',
              fontWeight: 800,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <WifiOff size={20} color="#4CAF50" />
            MANGÁS & OFFLINE
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
            Leitor de Mangás &{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #4CAF50 0%, #FFC36B 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              Downloads
            </span>
          </h2>
        </div>

        {/* Center: Smartphone Mockup with Split Features */}
        <div style={{ transform: 'scale(1.12)' }}>
          <DeviceMockup type="phone" delay={5} rotation={0}>
            <div
              style={{
                flex: 1,
                backgroundColor: '#140C08',
                display: 'flex',
                flexDirection: 'column',
                padding: '16px',
                paddingTop: '36px',
                gap: '14px',
              }}
            >
              {/* Feature 1: Manga Card */}
              <div
                style={{
                  backgroundColor: '#241712',
                  border: '1.5px solid rgba(245,163,79,0.35)',
                  borderRadius: '16px',
                  padding: '14px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '8px',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#FFE3AF', fontWeight: 800, fontSize: '13px' }}>
                    <BookOpen size={16} /> Leitor MangaDex
                  </div>
                  <span style={{ fontSize: '10px', backgroundColor: 'rgba(230,123,45,0.2)', color: AppColors.primaryLight, padding: '2px 6px', borderRadius: '6px', fontWeight: 700 }}>
                    Webtoon
                  </span>
                </div>
                <div style={{ fontSize: '14px', fontWeight: 800, color: '#FFF' }}>
                  Chainsaw Man — Cap. 164
                </div>
                <div
                  style={{
                    height: '70px',
                    borderRadius: '8px',
                    background: 'radial-gradient(circle, rgba(245,163,79,0.2) 0%, #1A0E08 90%)',
                    border: '1px dashed rgba(245,163,79,0.3)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '12px',
                    color: '#FFE3AF',
                    fontWeight: 700,
                  }}
                >
                  ⚡ Leitura vertical super suave
                </div>
              </div>

              {/* Feature 2: Download Manager Card */}
              <div
                style={{
                  backgroundColor: '#241712',
                  border: '1.5px solid rgba(76,175,80,0.4)',
                  borderRadius: '16px',
                  padding: '14px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#A5D6A7', fontWeight: 800, fontSize: '13px' }}>
                    <Download size={16} /> Download Offline
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', color: AppColors.success, fontWeight: 800, fontSize: '12px' }}>
                    <CheckCircle2 size={14} />
                    {downloadProgress === 100 ? 'Concluído' : `${downloadProgress}%`}
                  </div>
                </div>
                <div style={{ fontSize: '14px', fontWeight: 800, color: '#FFF' }}>
                  Solo Leveling — Episódio 12 (FHD)
                </div>
                <div style={{ height: '8px', backgroundColor: 'rgba(255,255,255,0.1)', borderRadius: '4px', overflow: 'hidden' }}>
                  <div
                    style={{
                      width: `${downloadProgress}%`,
                      height: '100%',
                      backgroundColor: downloadProgress === 100 ? AppColors.success : AppColors.primary,
                      boxShadow: '0 0 8px rgba(76,175,80,0.8)',
                    }}
                  />
                </div>
              </div>
            </div>
          </DeviceMockup>
        </div>

        {/* Bottom Tag */}
        <div
          style={{
            backgroundColor: 'rgba(38, 23, 17, 0.95)',
            border: '2px solid rgba(76, 175, 80, 0.6)',
            padding: '14px 28px',
            borderRadius: '30px',
            color: '#FFF8F1',
            fontSize: '20px',
            fontWeight: 800,
            boxShadow: '0 8px 30px rgba(0,0,0,0.7)',
            display: 'flex',
            alignItems: 'center',
            gap: '10px',
          }}
        >
          <Smartphone size={22} color={AppColors.success} />
          Assista no metrô, avião ou sem sinal!
        </div>
      </div>
    </AbsoluteFill>
  );
};
