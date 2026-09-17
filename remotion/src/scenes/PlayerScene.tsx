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
  Play,
  FastForward,
  Volume2,
  Maximize2,
  Zap,
  Sliders,
  RotateCcw,
  CheckCircle2,
  Flame,
} from 'lucide-react';

export const PlayerScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  // Entrance spring
  const textProgress = spring({
    frame,
    fps,
    config: { damping: 14, stiffness: 110 },
  });

  const textX = interpolate(textProgress, [0, 1], [-50, 0]);
  const textOpacity = interpolate(frame, [0, 10], [0, 1]);

  // Video progress bar interpolation
  const videoProgress = interpolate(frame, [0, durationInFrames], [25, 78], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // AniSkip Button highlight & press animation
  const aniSkipPop = spring({
    frame: frame - 25,
    fps,
    config: { damping: 10, stiffness: 140 },
  });

  // Simulate skip button click at frame 50
  const isClicked = frame >= 50;
  const clickScale = interpolate(
    frame,
    [48, 52, 58],
    [1, 0.88, 1],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

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
        {/* Left Column: Feature highlights */}
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
              backgroundColor: 'rgba(255, 179, 0, 0.15)',
              border: '1px solid rgba(255, 179, 0, 0.5)',
              padding: '6px 16px',
              borderRadius: '20px',
              color: '#FFB300',
              fontSize: '14px',
              fontWeight: 700,
              width: 'fit-content',
              textTransform: 'uppercase',
              letterSpacing: '1px',
            }}
          >
            <Zap size={16} /> Player Ultra Rápido
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
            Reprodução Imersiva com{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #FFB300 0%, #FFC36B 50%, #E67B2D 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              AniSkip Integrado
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
            Diga adeus a ficar adiantando manualmente a música tema. Pule
            aberturas e encerramentos com inteligência e assista direto ao que
            importa.
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '8px' }}>
            <Badge
              variant="accent"
              icon={<FastForward size={20} />}
              label="Pular Abertura & Encerramento (AniSkip)"
              sublabel="Detecção automatizada de timestamps de abertura"
              delay={15}
            />
            <Badge
              icon={<Sliders size={20} />}
              label="Qualidade até 1080p & Ajuste de Velocidade"
              sublabel="Opções de 0.5x até 2.0x e seleção de resolução"
              delay={25}
            />
            <Badge
              icon={<CheckCircle2 size={20} />}
              label="Retomada Instantânea de Onde Parou"
              sublabel="Histórico salvo automaticamente no dispositivo"
              delay={35}
            />
          </div>
        </div>

        {/* Right Column: Custom Video Player Mockup */}
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <DeviceMockup type="desktop" delay={10} rotation={1.5} scale={0.92}>
            {/* Player Container */}
            <div
              style={{
                flex: 1,
                backgroundColor: '#090503',
                position: 'relative',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                padding: '24px',
                overflow: 'hidden',
              }}
            >
              {/* Simulated Anime Scene Gradient Backdrop */}
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  background: `
                    radial-gradient(circle at 60% 40%, rgba(230,123,45,0.35) 0%, transparent 60%),
                    linear-gradient(135deg, #1C0F0A 0%, #0D0705 100%)
                  `,
                }}
              />

              {/* Animated Cinematic Lights / Streaks */}
              <div
                style={{
                  position: 'absolute',
                  top: '30%',
                  left: '20%',
                  width: '300px',
                  height: '180px',
                  borderRadius: '50%',
                  background: 'radial-gradient(circle, rgba(245,163,79,0.3) 0%, transparent 70%)',
                  filter: 'blur(30px)',
                  transform: `scale(${1 + Math.sin(frame / 12) * 0.1})`,
                }}
              />

              {/* Player Top Bar */}
              <div
                style={{
                  zIndex: 10,
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <div>
                  <h4 style={{ margin: 0, fontSize: '18px', fontWeight: 800, color: '#FFF' }}>
                    Jujutsu Kaisen — Episódio 17
                  </h4>
                  <span style={{ fontSize: '12px', color: AppColors.textTertiary }}>
                    Temporada 2 • Áudio Japonês (Legendas PT-BR)
                  </span>
                </div>

                <div style={{ display: 'flex', gap: '8px' }}>
                  <span
                    style={{
                      backgroundColor: 'rgba(230,123,45,0.25)',
                      border: '1px solid rgba(245,163,79,0.5)',
                      color: AppColors.primaryLight,
                      padding: '4px 10px',
                      borderRadius: '8px',
                      fontSize: '11px',
                      fontWeight: 800,
                    }}
                  >
                    1080p FHD
                  </span>
                  <span
                    style={{
                      backgroundColor: 'rgba(255,255,255,0.1)',
                      color: '#FFF',
                      padding: '4px 10px',
                      borderRadius: '8px',
                      fontSize: '11px',
                      fontWeight: 700,
                    }}
                  >
                    1.25x
                  </span>
                </div>
              </div>

              {/* Center AniSkip Popup Notification */}
              <div
                style={{
                  zIndex: 20,
                  alignSelf: 'center',
                  transform: `scale(${aniSkipPop * clickScale})`,
                  display: 'flex',
                  alignItems: 'center',
                  gap: '14px',
                  backgroundColor: isClicked ? 'rgba(76, 175, 80, 0.95)' : 'rgba(245, 163, 79, 0.95)',
                  color: '#120B08',
                  padding: '12px 24px',
                  borderRadius: '40px',
                  boxShadow: isClicked
                    ? '0 0 35px rgba(76, 175, 80, 0.7)'
                    : '0 0 35px rgba(245, 163, 79, 0.7)',
                  border: '2px solid #FFF',
                  fontWeight: 800,
                  fontSize: '15px',
                  transition: 'background-color 0.2s',
                }}
              >
                <FastForward size={22} color="#120B08" />
                {isClicked ? (
                  <span>✓ Abertura Pulada com Sucesso!</span>
                ) : (
                  <span>Pular Abertura (01:30 - 03:00)</span>
                )}
              </div>

              {/* Player Bottom Controls */}
              <div
                style={{
                  zIndex: 10,
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '12px',
                  background: 'linear-gradient(0deg, rgba(0,0,0,0.85) 0%, transparent 100%)',
                  padding: '12px',
                  borderRadius: '12px',
                }}
              >
                {/* Timeline Progress Bar */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                  <span style={{ fontSize: '12px', color: '#FFF', fontWeight: 600 }}>
                    {isClicked ? '03:10' : '01:45'}
                  </span>
                  <div
                    style={{
                      flex: 1,
                      height: '6px',
                      backgroundColor: 'rgba(255,255,255,0.2)',
                      borderRadius: '3px',
                      position: 'relative',
                      overflow: 'hidden',
                    }}
                  >
                    <div
                      style={{
                        position: 'absolute',
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: `${videoProgress}%`,
                        backgroundColor: AppColors.primary,
                        borderRadius: '3px',
                        boxShadow: '0 0 10px rgba(230,123,45,0.8)',
                      }}
                    />
                  </div>
                  <span style={{ fontSize: '12px', color: AppColors.textTertiary, fontWeight: 600 }}>
                    23:45
                  </span>
                </div>

                {/* Control Buttons Bar */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '18px' }}>
                    <div
                      style={{
                        width: '36px',
                        height: '36px',
                        borderRadius: '50%',
                        backgroundColor: AppColors.primary,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        boxShadow: '0 0 15px rgba(230,123,45,0.6)',
                      }}
                    >
                      <Play size={16} fill="#FFF" color="#FFF" />
                    </div>
                    <RotateCcw size={18} color="#FFF" />
                    <FastForward size={18} color="#FFF" />
                    <Volume2 size={18} color="#FFF" />
                  </div>

                  <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
                    <span style={{ fontSize: '13px', color: AppColors.accentLight, fontWeight: 700 }}>
                      ⚡ Servidor 1 (Ultra Rápido)
                    </span>
                    <Maximize2 size={18} color="#FFF" />
                  </div>
                </div>
              </div>
            </div>
          </DeviceMockup>
        </div>
      </div>
    </AbsoluteFill>
  );
};
