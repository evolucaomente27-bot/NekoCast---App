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
  Compass,
  Flame,
  Search,
  Star,
  Play,
  Layers,
  Sparkles,
  TrendingUp,
} from 'lucide-react';

export const CatalogScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Entrance spring for left text block
  const textProgress = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 110 },
  });

  const textX = interpolate(textProgress, [0, 1], [-50, 0]);
  const textOpacity = interpolate(frame, [0, 10], [0, 1]);

  // Card list horizontal scroll simulation
  const shelfScroll = interpolate(frame, [20, durationInFrames], [0, -140], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Exit transition
  const exitProgress = interpolate(
    frame,
    [durationInFrames - 15, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  // Sample anime cards for UI mockup
  const animeCards = [
    {
      title: 'Solo Leveling: Arise',
      score: '9.2',
      episodes: 'Ep 12 / 12',
      genre: 'Ação • Fantasia',
      bgGradient: 'linear-gradient(135deg, #1E1B4B 0%, #3B0764 100%)',
      accentColor: '#818CF8',
    },
    {
      title: 'Frieren: Beyond Journey',
      score: '9.4',
      episodes: 'Ep 28 / 28',
      genre: 'Aventura • Magia',
      bgGradient: 'linear-gradient(135deg, #064E3B 0%, #047857 100%)',
      accentColor: '#34D399',
    },
    {
      title: 'Demon Slayer: Hashira',
      score: '8.9',
      episodes: 'Ep 8 / 8',
      genre: 'Shounen • Sobrenatural',
      bgGradient: 'linear-gradient(135deg, #7F1D1D 0%, #991B1B 100%)',
      accentColor: '#F87171',
    },
    {
      title: 'Jujutsu Kaisen S2',
      score: '9.0',
      episodes: 'Ep 23 / 23',
      genre: 'Ação • Sobrenatural',
      bgGradient: 'linear-gradient(135deg, #172554 0%, #1E3A8A 100%)',
      accentColor: '#60A5FA',
    },
  ];

  return (
    <AbsoluteFill style={{ opacity: exitProgress }}>
      <Background glowIntensity={1.1} />

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
        {/* Left Column: Feature highlights */}
        <div
          style={{
            flex: 1,
            maxWidth: '680px',
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
              backgroundColor: 'rgba(230, 123, 45, 0.15)',
              border: '1px solid rgba(245, 163, 79, 0.4)',
              padding: '6px 16px',
              borderRadius: '20px',
              color: AppColors.primaryLight,
              fontSize: '14px',
              fontWeight: 700,
              width: 'fit-content',
              textTransform: 'uppercase',
              letterSpacing: '1px',
            }}
          >
            <Compass size={16} /> Exploração Sem Limites
          </div>

          <h2
            style={{
              fontSize: '54px',
              fontWeight: 900,
              color: AppColors.textPrimary,
              margin: 0,
              lineHeight: 1.1,
              letterSpacing: '-1px',
            }}
          >
            Descubra milhares de{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #F5A34F 0%, #FFC36B 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              Animes e Episódios
            </span>
          </h2>

          <p
            style={{
              fontSize: '20px',
              color: AppColors.textSecondary,
              lineHeight: 1.5,
              margin: 0,
            }}
          >
            Acompanhe temporadas em tempo real, navegue por gêneros e acesse
            múltiplas fontes de streaming com rapidez e sem travamentos.
          </p>

          {/* Badges */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '10px' }}>
            <Badge
              icon={<TrendingUp size={20} />}
              label="Temporadas & Lançamentos em Alta"
              sublabel="Metadados sincronizados com Jikan, MyAnimeList e AniList"
              delay={15}
            />
            <Badge
              icon={<Layers size={20} />}
              label="Múltiplas Fontes Integradas"
              sublabel="Selecione o melhor servidor para cada transmissão"
              delay={25}
            />
            <Badge
              icon={<Search size={20} />}
              label="Busca Rápida e Histórico Salvo"
              sublabel="Encontre qualquer título instantaneamente"
              delay={35}
            />
          </div>
        </div>

        {/* Right Column: Interactive App UI Mockup */}
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <DeviceMockup type="desktop" delay={10} rotation={-1.5} scale={0.92}>
            {/* App Header */}
            <div
              style={{
                height: '52px',
                backgroundColor: AppColors.surface,
                borderBottom: '1px solid rgba(230, 123, 45, 0.2)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0 24px',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div
                  style={{
                    width: '30px',
                    height: '30px',
                    borderRadius: '8px',
                    backgroundColor: AppColors.primary,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 900,
                    color: '#FFF',
                    fontSize: '16px',
                  }}
                >
                  N
                </div>
                <span style={{ fontWeight: 800, color: AppColors.textPrimary, fontSize: '18px' }}>
                  NekoCast
                </span>
              </div>

              {/* Navigation Tabs */}
              <div style={{ display: 'flex', gap: '18px', fontSize: '14px', fontWeight: 600 }}>
                <span style={{ color: AppColors.primaryLight, borderBottom: `2px solid ${AppColors.primaryLight}`, paddingBottom: '4px' }}>
                  Início
                </span>
                <span style={{ color: AppColors.textSecondary }}>Mangás</span>
                <span style={{ color: AppColors.textSecondary }}>Salvos</span>
                <span style={{ color: AppColors.textSecondary }}>Downloads</span>
              </div>

              {/* Search input mock */}
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '8px',
                  backgroundColor: AppColors.background,
                  padding: '6px 14px',
                  borderRadius: '20px',
                  border: '1px solid rgba(245,163,79,0.2)',
                  fontSize: '12px',
                  color: AppColors.textTertiary,
                  width: '160px',
                }}
              >
                <Search size={14} color={AppColors.primaryLight} />
                <span>Buscar anime...</span>
              </div>
            </div>

            {/* App Body Content */}
            <div
              style={{
                flex: 1,
                padding: '20px',
                display: 'flex',
                flexDirection: 'column',
                gap: '16px',
                overflow: 'hidden',
                backgroundColor: '#160E0A',
              }}
            >
              {/* Featured Hero Banner */}
              <div
                style={{
                  height: '160px',
                  borderRadius: '16px',
                  background: 'linear-gradient(90deg, rgba(230,123,45,0.9) 0%, rgba(139,92,56,0.85) 60%, rgba(27,18,13,0.95) 100%)',
                  padding: '20px 24px',
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.4)',
                  position: 'relative',
                  overflow: 'hidden',
                }}
              >
                <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', zIndex: 2 }}>
                  <span
                    style={{
                      fontSize: '11px',
                      fontWeight: 800,
                      color: '#FFF',
                      backgroundColor: 'rgba(0,0,0,0.4)',
                      padding: '3px 10px',
                      borderRadius: '12px',
                      width: 'fit-content',
                    }}
                  >
                    🔥 DESTAQUE DA TEMPORADA
                  </span>
                  <h3 style={{ margin: 0, fontSize: '24px', fontWeight: 900, color: '#FFF' }}>
                    Solo Leveling: Temporada 2
                  </h3>
                  <p style={{ margin: 0, fontSize: '13px', color: '#FFE3AF', maxWidth: '340px' }}>
                    Novo episódio disponível com suporte a áudio dual e alta resolução.
                  </p>
                  <div
                    style={{
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: '6px',
                      backgroundColor: '#FFF',
                      color: '#120B08',
                      padding: '6px 16px',
                      borderRadius: '20px',
                      fontSize: '12px',
                      fontWeight: 800,
                      marginTop: '4px',
                      width: 'fit-content',
                    }}
                  >
                    <Play size={12} fill="#120B08" /> Assistir Agora
                  </div>
                </div>

                {/* Decorative glow badge */}
                <div
                  style={{
                    width: '100px',
                    height: '100px',
                    borderRadius: '50%',
                    background: 'radial-gradient(circle, rgba(255,195,107,0.4) 0%, transparent 70%)',
                  }}
                />
              </div>

              {/* Anime Carousel Shelf */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '15px', fontWeight: 800, color: AppColors.textPrimary }}>
                    ⚡ Mais Populares no Brasil
                  </span>
                  <span style={{ fontSize: '12px', color: AppColors.primaryLight, fontWeight: 600 }}>
                    Ver todos →
                  </span>
                </div>

                {/* Horizontal Cards Container */}
                <div
                  style={{
                    display: 'flex',
                    gap: '14px',
                    transform: `translateX(${shelfScroll}px)`,
                  }}
                >
                  {animeCards.map((anime, idx) => (
                    <div
                      key={idx}
                      style={{
                        width: '190px',
                        height: '180px',
                        borderRadius: '14px',
                        background: anime.bgGradient,
                        border: '1px solid rgba(245, 163, 79, 0.25)',
                        padding: '14px',
                        display: 'flex',
                        flexDirection: 'column',
                        justifyContent: 'space-between',
                        boxShadow: '0 8px 16px rgba(0,0,0,0.5)',
                        flexShrink: 0,
                        position: 'relative',
                        overflow: 'hidden',
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <span
                          style={{
                            fontSize: '11px',
                            fontWeight: 700,
                            color: '#FFF',
                            backgroundColor: 'rgba(0,0,0,0.5)',
                            padding: '2px 8px',
                            borderRadius: '8px',
                          }}
                        >
                          {anime.episodes}
                        </span>
                        <span
                          style={{
                            fontSize: '11px',
                            fontWeight: 800,
                            color: '#FFD700',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '3px',
                          }}
                        >
                          <Star size={12} fill="#FFD700" /> {anime.score}
                        </span>
                      </div>

                      <div>
                        <div
                          style={{
                            fontSize: '11px',
                            color: anime.accentColor,
                            fontWeight: 600,
                            marginBottom: '2px',
                          }}
                        >
                          {anime.genre}
                        </div>
                        <div
                          style={{
                            fontSize: '14px',
                            fontWeight: 800,
                            color: '#FFF',
                            lineHeight: 1.2,
                          }}
                        >
                          {anime.title}
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </DeviceMockup>
        </div>
      </div>
    </AbsoluteFill>
  );
};
