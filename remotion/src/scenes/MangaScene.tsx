import React from 'react';
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import { Background } from '../components/Background';
import { Badge } from '../components/Badge';
import { DeviceMockup } from '../components/DeviceMockup';
import { AppColors } from '../theme/colors';
import {
  BookOpen,
  Bookmark,
  Smartphone,
  Layers,
  Sparkles,
  ChevronRight,
  Sun,
  Moon,
} from 'lucide-react';

export const MangaScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Text entrance
  const textProgress = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 110 },
  });
  const textX = interpolate(textProgress, [0, 1], [-50, 0]);
  const textOpacity = interpolate(frame, [0, 10], [0, 1]);

  // Page scroll inside mockup
  const pageScroll = interpolate(frame, [15, durationInFrames], [0, -220], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const exitProgress = interpolate(
    frame,
    [durationInFrames - 15, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  return (
    <AbsoluteFill style={{ opacity: exitProgress }}>
      <Background glowIntensity={1.2} />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 80px',
          zIndex: 10,
        }}
      >
        {/* Left Column: Features */}
        <div
          style={{
            flex: 1,
            maxWidth: '660px',
            transform: `translateX(${textX}px)`,
            opacity: textOpacity,
            display: 'flex',
            flexDirection: 'column',
            gap: '24px',
          }}
        >
          <div
            style={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: '8px',
              backgroundColor: 'rgba(244, 202, 120, 0.2)',
              border: '1.5px solid rgba(244, 202, 120, 0.6)',
              padding: '8px 18px',
              borderRadius: '24px',
              color: '#FFE3AF',
              fontSize: '15px',
              fontWeight: 800,
              width: 'fit-content',
              textTransform: 'uppercase',
              letterSpacing: '1px',
            }}
          >
            <BookOpen size={18} /> Leitor de Mangás Integrado
          </div>

          <h2
            style={{
              fontSize: '56px',
              fontWeight: 900,
              color: '#FFF8F1',
              margin: 0,
              lineHeight: 1.1,
              letterSpacing: '-1px',
            }}
          >
            Leia seus{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #FFE3AF 0%, #F5A34F 50%, #FFC36B 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                textShadow: '0 0 35px rgba(245, 163, 79, 0.5)',
              }}
            >
              Mangás Favoritos
            </span>
          </h2>

          <p
            style={{
              fontSize: '21px',
              color: '#D8C5B7',
              lineHeight: 1.5,
              margin: 0,
            }}
          >
            Acesse capítulos traduzidos diretamente no app com um leitor fluído,
            suporte a modo contínuo (Webtoon) e navegação adaptada para telas
            touch e desktop.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '6px' }}>
            <Badge
              variant="accent"
              icon={<Layers size={22} />}
              label="Integração Direta com MangaDex"
              sublabel="Milhares de títulos e atualizações frequentes de capítulos"
              delay={15}
            />
            <Badge
              icon={<Smartphone size={22} />}
              label="Modo Webtoon & Página Dupla"
              sublabel="Experiência de leitura vertical ultra fluida e zoom"
              delay={25}
            />
            <Badge
              icon={<Bookmark size={22} />}
              label="Marcador e Progresso Automático"
              sublabel="Continue exatamente de onde você parou de ler"
              delay={35}
            />
          </div>
        </div>

        {/* Right Column: Phone Mockup with Manga Reader */}
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <DeviceMockup type="phone" delay={10} rotation={2} scale={0.98}>
            {/* Manga Header */}
            <div
              style={{
                height: '62px',
                paddingTop: '20px',
                paddingLeft: '18px',
                paddingRight: '18px',
                backgroundColor: 'rgba(27, 18, 13, 0.98)',
                borderBottom: '1px solid rgba(245,163,79,0.3)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                zIndex: 10,
              }}
            >
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontSize: '14px', fontWeight: 800, color: '#FFF' }}>
                  Chainsaw Man
                </span>
                <span style={{ fontSize: '11px', color: AppColors.primaryLight, fontWeight: 600 }}>
                  Capítulo 164 • Pág. 12/24
                </span>
              </div>
              <div
                style={{
                  backgroundColor: 'rgba(230,123,45,0.25)',
                  border: '1px solid rgba(245,163,79,0.4)',
                  color: '#FFE3AF',
                  padding: '4px 10px',
                  borderRadius: '12px',
                  fontSize: '11px',
                  fontWeight: 800,
                }}
              >
                Webtoon
              </div>
            </div>

            {/* Manga Pages Scrolling Container */}
            <div
              style={{
                flex: 1,
                overflow: 'hidden',
                backgroundColor: '#0A0604',
                position: 'relative',
                padding: '10px',
              }}
            >
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '14px',
                  transform: `translateY(${pageScroll}px)`,
                }}
              >
                {/* Mock Manga Panel 1 */}
                <div
                  style={{
                    height: '270px',
                    borderRadius: '14px',
                    background: 'linear-gradient(180deg, #2D1A10 0%, #1A0E08 100%)',
                    border: '1.5px solid rgba(245,163,79,0.35)',
                    padding: '16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                    boxShadow: '0 8px 24px rgba(0,0,0,0.6)',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '12px', color: '#FFE3AF', fontWeight: 800 }}>
                      ⚡ CAPÍTULO 164
                    </span>
                    <span
                      style={{
                        fontSize: '10px',
                        backgroundColor: 'rgba(230,123,45,0.2)',
                        color: AppColors.primaryLight,
                        padding: '2px 8px',
                        borderRadius: '6px',
                        fontWeight: 700,
                      }}
                    >
                      MangaDex
                    </span>
                  </div>

                  <div
                    style={{
                      flex: 1,
                      margin: '12px 0',
                      borderRadius: '10px',
                      background: 'radial-gradient(circle at center, rgba(245,163,79,0.25) 0%, rgba(20,12,8,0.95) 85%)',
                      border: '1px dashed rgba(245,163,79,0.4)',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                      padding: '16px',
                    }}
                  >
                    <span style={{ fontSize: '32px' }}>📖</span>
                    <span style={{ fontSize: '14px', color: '#FFF8F1', fontWeight: 800, textAlign: 'center' }}>
                      Páginas em Alta Definição
                    </span>
                    <span style={{ fontSize: '11px', color: AppColors.accentLight, textAlign: 'center' }}>
                      Renderização rápida e sem perdas
                    </span>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '11px', color: '#A58B7B' }}>
                    <span>Tradução: Scan BR</span>
                    <span>HD 1080p</span>
                  </div>
                </div>

                {/* Mock Manga Panel 2 */}
                <div
                  style={{
                    height: '260px',
                    borderRadius: '14px',
                    background: 'linear-gradient(180deg, #24150D 0%, #150C07 100%)',
                    border: '1.5px solid rgba(245,163,79,0.35)',
                    padding: '16px',
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'space-between',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span style={{ fontSize: '12px', color: AppColors.primaryLight, fontWeight: 800 }}>
                      🔥 MODO WEBTOON CONTÍNUO
                    </span>
                  </div>

                  <div
                    style={{
                      flex: 1,
                      margin: '12px 0',
                      borderRadius: '10px',
                      background: 'radial-gradient(circle at center, rgba(244,202,120,0.2) 0%, rgba(20,12,8,0.95) 85%)',
                      border: '1px dashed rgba(244,202,120,0.4)',
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      gap: '8px',
                      padding: '16px',
                    }}
                  >
                    <span style={{ fontSize: '30px' }}>⚡</span>
                    <span style={{ fontSize: '14px', color: '#FFE3AF', fontWeight: 800 }}>
                      Rolagem Vertical Infinita
                    </span>
                  </div>
                </div>
              </div>
            </div>

            {/* Bottom floating page bar */}
            <div
              style={{
                height: '46px',
                backgroundColor: 'rgba(27, 18, 13, 0.98)',
                borderTop: '1px solid rgba(230,123,45,0.3)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0 18px',
                fontSize: '12px',
                color: AppColors.textTertiary,
              }}
            >
              <span style={{ fontWeight: 600 }}>← Anterior</span>
              <span style={{ color: '#FFF', fontWeight: 800, backgroundColor: 'rgba(0,0,0,0.4)', padding: '3px 10px', borderRadius: '10px' }}>
                12 / 24
              </span>
              <span style={{ color: AppColors.primaryLight, fontWeight: 800 }}>Próximo →</span>
            </div>
          </DeviceMockup>
        </div>
      </div>
    </AbsoluteFill>
  );
};
