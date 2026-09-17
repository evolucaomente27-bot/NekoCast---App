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
  Download,
  CheckCircle2,
  HardDrive,
  Pause,
  Smartphone,
  Monitor,
  Globe,
  Apple,
  Terminal,
  WifiOff,
  FolderDown,
} from 'lucide-react';

export const DownloadsScene: React.FC = () => {
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

  // Animated download progress percentages
  const progress1 = Math.min(100, Math.floor(interpolate(frame, [0, 80], [30, 100])));
  const progress2 = Math.min(100, Math.floor(interpolate(frame, [10, 90], [15, 68])));

  const exitProgress = interpolate(
    frame,
    [durationInFrames - 15, durationInFrames],
    [1, 0],
    { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' }
  );

  // Platform badges
  const platforms = [
    { name: 'Android', icon: <Smartphone size={16} /> },
    { name: 'Windows', icon: <Monitor size={16} /> },
    { name: 'Web', icon: <Globe size={16} /> },
    { name: 'Linux', icon: <Terminal size={16} /> },
    { name: 'iOS / macOS', icon: <Apple size={16} /> },
  ];

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
              backgroundColor: 'rgba(76, 175, 80, 0.15)',
              border: '1px solid rgba(76, 175, 80, 0.5)',
              padding: '6px 16px',
              borderRadius: '20px',
              color: AppColors.success,
              fontSize: '14px',
              fontWeight: 700,
              width: 'fit-content',
              textTransform: 'uppercase',
              letterSpacing: '1px',
            }}
          >
            <WifiOff size={16} /> Liberdade Offline & Multiplataforma
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
            Assista Onde Quiser,{' '}
            <span
              style={{
                background: 'linear-gradient(90deg, #4CAF50 0%, #FFC36B 100%)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              Mesmo Sem Internet
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
            Baixe episódios em lote com controle total de qualidade, pausa e
            retomada inteligente. Disponível para todas as plataformas.
          </p>

          {/* Platform Badges Row */}
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px' }}>
            {platforms.map((p, idx) => {
              const pillSpring = spring({
                frame: frame - 15 - idx * 6,
                fps,
                config: { damping: 12 },
              });
              return (
                <div
                  key={idx}
                  style={{
                    transform: `scale(${pillSpring})`,
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                    backgroundColor: 'rgba(36, 23, 18, 0.9)',
                    border: '1px solid rgba(245, 163, 79, 0.3)',
                    padding: '8px 16px',
                    borderRadius: '16px',
                    fontSize: '14px',
                    fontWeight: 700,
                    color: AppColors.textPrimary,
                  }}
                >
                  <span style={{ color: AppColors.primaryLight }}>{p.icon}</span>
                  {p.name}
                </div>
              );
            })}
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '4px' }}>
            <Badge
              icon={<FolderDown size={20} />}
              label="Download Inteligente & Fila de Espera"
              sublabel="Baixe temporadas inteiras com velocidade otimizada"
              delay={30}
            />
            <Badge
              icon={<HardDrive size={20} />}
              label="Gerenciamento de Armazenamento"
              sublabel="Monitore o espaço em disco diretamente pelo aplicativo"
              delay={40}
            />
          </div>
        </div>

        {/* Right Column: Downloads Manager Mockup */}
        <div style={{ flex: 1, display: 'flex', justifyContent: 'center' }}>
          <DeviceMockup type="desktop" delay={10} rotation={-1.5} scale={0.92}>
            <div
              style={{
                flex: 1,
                backgroundColor: '#160E0A',
                padding: '24px',
                display: 'flex',
                flexDirection: 'column',
                gap: '18px',
              }}
            >
              {/* Header */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <Download size={22} color={AppColors.primaryLight} />
                  <span style={{ fontSize: '20px', fontWeight: 800, color: '#FFF' }}>
                    Downloads Offline
                  </span>
                </div>
                <div
                  style={{
                    fontSize: '12px',
                    backgroundColor: 'rgba(230,123,45,0.2)',
                    color: AppColors.primaryLight,
                    padding: '4px 12px',
                    borderRadius: '12px',
                    fontWeight: 700,
                  }}
                >
                  Espaço Livre: 48.2 GB
                </div>
              </div>

              {/* Download Item 1 (Completed) */}
              <div
                style={{
                  backgroundColor: AppColors.surface,
                  border: '1px solid rgba(245,163,79,0.25)',
                  borderRadius: '16px',
                  padding: '16px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.3)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <h5 style={{ margin: 0, fontSize: '15px', fontWeight: 800, color: '#FFF' }}>
                      Solo Leveling — Episódio 12 (Final)
                    </h5>
                    <span style={{ fontSize: '12px', color: AppColors.textTertiary }}>
                      1080p FHD • 450 MB • Pronto para assistir
                    </span>
                  </div>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '6px',
                      color: AppColors.success,
                      fontWeight: 800,
                      fontSize: '13px',
                    }}
                  >
                    <CheckCircle2 size={16} />
                    {progress1 === 100 ? 'Concluído' : `${progress1}%`}
                  </div>
                </div>

                {/* Progress Bar */}
                <div
                  style={{
                    height: '8px',
                    backgroundColor: 'rgba(255,255,255,0.1)',
                    borderRadius: '4px',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${progress1}%`,
                      height: '100%',
                      backgroundColor: progress1 === 100 ? AppColors.success : AppColors.primary,
                      borderRadius: '4px',
                      boxShadow: progress1 === 100 ? '0 0 10px rgba(76,175,80,0.6)' : '0 0 10px rgba(230,123,45,0.6)',
                    }}
                  />
                </div>
              </div>

              {/* Download Item 2 (In Progress) */}
              <div
                style={{
                  backgroundColor: AppColors.surface,
                  border: '1px solid rgba(245,163,79,0.25)',
                  borderRadius: '16px',
                  padding: '16px',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '10px',
                  boxShadow: '0 4px 16px rgba(0,0,0,0.3)',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <h5 style={{ margin: 0, fontSize: '15px', fontWeight: 800, color: '#FFF' }}>
                      Frieren: Beyond Journey — Episódio 28
                    </h5>
                    <span style={{ fontSize: '12px', color: AppColors.textTertiary }}>
                      1080p FHD • Baixando a 18.4 MB/s • Restam 15s
                    </span>
                  </div>
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: '8px',
                      color: AppColors.primaryLight,
                      fontWeight: 800,
                      fontSize: '13px',
                    }}
                  >
                    <div
                      style={{
                        width: '24px',
                        height: '24px',
                        borderRadius: '50%',
                        backgroundColor: 'rgba(230,123,45,0.3)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                      }}
                    >
                      <Pause size={12} color="#FFF" />
                    </div>
                    {progress2}%
                  </div>
                </div>

                {/* Progress Bar */}
                <div
                  style={{
                    height: '8px',
                    backgroundColor: 'rgba(255,255,255,0.1)',
                    borderRadius: '4px',
                    overflow: 'hidden',
                  }}
                >
                  <div
                    style={{
                      width: `${progress2}%`,
                      height: '100%',
                      background: 'linear-gradient(90deg, #F5A34F 0%, #E67B2D 100%)',
                      borderRadius: '4px',
                      boxShadow: '0 0 12px rgba(245,163,79,0.7)',
                    }}
                  />
                </div>
              </div>
            </div>
          </DeviceMockup>
        </div>
      </div>
    </AbsoluteFill>
  );
};
