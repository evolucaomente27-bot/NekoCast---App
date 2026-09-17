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
import { Star, TrendingUp, Search, Layers, Play } from 'lucide-react';

export const VerticalCatalogScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Entrance
  const titleSpring = spring({
    frame,
    fps,
    config: { damping: 13, stiffness: 120 },
  });
  const titleY = interpolate(titleSpring, [0, 1], [-30, 0]);

  // Phone scale entrance
  const phoneSpring = spring({
    frame: frame - 10,
    fps,
    config: { damping: 14, stiffness: 100 },
  });

  const scrollY = interpolate(frame, [15, durationInFrames], [0, -120], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const exitProgress = interpolate(
    frame,
    [durationInFrames - 12, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  const animeList = [
    { title: 'Solo Leveling: Arise', ep: 'Ep 12', score: '★ 9.2', tag: 'Ação • Fantasia', bg: '#2A1B4B' },
    { title: 'Frieren: Beyond Journey', ep: 'Ep 28', score: '★ 9.4', tag: 'Aventura • Magia', bg: '#0A3B2B' },
    { title: 'Demon Slayer: Hashira', ep: 'Ep 8', score: '★ 8.9', tag: 'Shounen • Ação', bg: '#4A1212' },
    { title: 'Jujutsu Kaisen S2', ep: 'Ep 23', score: '★ 9.0', tag: 'Sobrenatural', bg: '#102048' },
  ];

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
            transform: `translateY(${titleY}px)`,
            textAlign: 'center',
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '12px',
          }}
        >
          <div
            style={{
              backgroundColor: 'rgba(230, 123, 45, 0.25)',
              border: '1.5px solid rgba(245, 163, 79, 0.55)',
              padding: '8px 22px',
              borderRadius: '24px',
              color: '#FFE3AF',
              fontSize: '18px',
              fontWeight: 800,
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <TrendingUp size={20} color="#FFC36B" />
            CATÁLOGO INFINITO
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
            Milhares de Animes em{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #F5A34F 0%, #FFC36B 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              Full HD 1080p
            </span>
          </h2>
        </div>

        {/* Center: Smartphone Mockup */}
        <div style={{ transform: `scale(${interpolate(phoneSpring, [0, 1], [0.8, 1.12])})` }}>
          <DeviceMockup type="phone" delay={10} rotation={0}>
            {/* App UI inside phone */}
            <div
              style={{
                flex: 1,
                backgroundColor: '#140C08',
                display: 'flex',
                flexDirection: 'column',
                padding: '16px',
                paddingTop: '32px',
                gap: '12px',
                overflow: 'hidden',
              }}
            >
              {/* Top search */}
              <div
                style={{
                  height: '40px',
                  borderRadius: '20px',
                  backgroundColor: '#241712',
                  border: '1px solid rgba(245,163,79,0.3)',
                  display: 'flex',
                  alignItems: 'center',
                  padding: '0 14px',
                  gap: '8px',
                  fontSize: '13px',
                  color: AppColors.textTertiary,
                }}
              >
                <Search size={16} color={AppColors.primaryLight} />
                <span>Buscar anime, autor, gênero...</span>
              </div>

              {/* Featured banner */}
              <div
                style={{
                  height: '130px',
                  borderRadius: '14px',
                  background: 'linear-gradient(135deg, #E67B2D 0%, #8B4A28 100%)',
                  padding: '14px',
                  display: 'flex',
                  flexDirection: 'column',
                  justifyContent: 'space-between',
                  boxShadow: '0 8px 20px rgba(0,0,0,0.5)',
                }}
              >
                <div>
                  <span style={{ fontSize: '10px', fontWeight: 800, color: '#FFF', backgroundColor: 'rgba(0,0,0,0.4)', padding: '2px 6px', borderRadius: '6px' }}>
                    EM ALTA
                  </span>
                  <div style={{ fontSize: '16px', fontWeight: 900, color: '#FFF', marginTop: '4px' }}>
                    Solo Leveling: Temporada 2
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', backgroundColor: '#FFF', color: '#120B08', padding: '4px 12px', borderRadius: '12px', width: 'fit-content', fontSize: '11px', fontWeight: 800 }}>
                  <Play size={10} fill="#120B08" /> Assistir Agora
                </div>
              </div>

              {/* Vertical list of anime cards */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', transform: `translateY(${scrollY}px)` }}>
                {animeList.map((item, idx) => (
                  <div
                    key={idx}
                    style={{
                      height: '62px',
                      borderRadius: '12px',
                      backgroundColor: item.bg,
                      border: '1px solid rgba(245,163,79,0.3)',
                      padding: '10px 14px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                    }}
                  >
                    <div>
                      <div style={{ fontSize: '13px', fontWeight: 800, color: '#FFF' }}>{item.title}</div>
                      <div style={{ fontSize: '10px', color: '#FFE3AF' }}>{item.tag}</div>
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '2px' }}>
                      <span style={{ fontSize: '11px', color: '#FFD700', fontWeight: 800 }}>{item.score}</span>
                      <span style={{ fontSize: '10px', color: '#FFF', backgroundColor: 'rgba(0,0,0,0.5)', padding: '1px 6px', borderRadius: '6px' }}>
                        {item.ep}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </DeviceMockup>
        </div>

        {/* Bottom Pill */}
        <div
          style={{
            backgroundColor: 'rgba(38, 23, 17, 0.95)',
            border: '2px solid rgba(245, 163, 79, 0.5)',
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
          <Layers size={22} color={AppColors.primaryLight} />
          Múltiplas Fontes & Sem Travamentos!
        </div>
      </div>
    </AbsoluteFill>
  );
};
