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
import { Download, Github, ShieldCheck, Heart, Sparkles } from 'lucide-react';

export const VerticalOutroScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoSpring = spring({
    frame,
    fps,
    config: { damping: 12, stiffness: 100 },
  });
  const logoScale = interpolate(logoSpring, [0, 1], [0.3, 1]);

  const ctaSpring = spring({
    frame: frame - 20,
    fps,
    config: { damping: 12, stiffness: 130 },
  });
  const ctaScale = interpolate(ctaSpring, [0, 1], [0.8, 1]);

  const pulse = 1 + Math.sin(frame / 15) * 0.05;

  return (
    <AbsoluteFill>
      <Background glowIntensity={1.8} />

      {/* Central Radiance Glow */}
      <div
        style={{
          position: 'absolute',
          top: '42%',
          left: '50%',
          transform: 'translate(-50%, -50%)',
          width: '700px',
          height: '700px',
          borderRadius: '50%',
          background: 'radial-gradient(circle, rgba(245, 163, 79, 0.45) 0%, rgba(230, 123, 45, 0.2) 50%, transparent 75%)',
          filter: 'blur(50px)',
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
          padding: '40px',
          zIndex: 10,
          textAlign: 'center',
        }}
      >
        {/* Logo */}
        <div
          style={{
            transform: `scale(${logoScale * pulse})`,
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
              border: '3px solid rgba(245, 163, 79, 0.8)',
              boxShadow: '0 25px 60px rgba(0,0,0,0.9), 0 0 60px rgba(230, 123, 45, 0.6)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '16px',
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

        {/* Title */}
        <h1
          style={{
            fontSize: '62px',
            fontWeight: 900,
            margin: '0 0 16px 0',
            lineHeight: 1.15,
            letterSpacing: '-1.5px',
            background: 'linear-gradient(180deg, #FFFFFF 0%, #FFE3AF 40%, #E67B2D 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            textShadow: '0 10px 40px rgba(230, 123, 45, 0.5)',
          }}
        >
          Baixe o NekoCast Agora!
        </h1>

        <p
          style={{
            fontSize: '24px',
            color: '#FFE3AF',
            margin: '0 0 36px 0',
            fontWeight: 700,
          }}
        >
          100% Gratuito & Livre de Anúncios Abusivos
        </p>

        {/* CTA Button */}
        <div
          style={{
            transform: `scale(${ctaScale})`,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: '24px',
            width: '100%',
            maxWidth: '520px',
          }}
        >
          <div
            style={{
              width: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '14px',
              background: 'linear-gradient(135deg, #F5A34F 0%, #E67B2D 100%)',
              color: '#120B08',
              padding: '20px 32px',
              borderRadius: '50px',
              fontSize: '26px',
              fontWeight: 900,
              boxShadow: '0 12px 40px rgba(230, 123, 45, 0.7), 0 0 25px rgba(255, 195, 107, 0.5)',
              border: '3px solid #FFE3AF',
            }}
          >
            <Download size={30} color="#120B08" strokeWidth={3} />
            BAIXAR GRATUITAMENTE
          </div>

          {/* GitHub & Platform Tags */}
          <div
            style={{
              display: 'flex',
              flexDirection: 'column',
              gap: '12px',
              width: '100%',
            }}
          >
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                backgroundColor: 'rgba(38, 23, 17, 0.95)',
                border: '1.5px solid rgba(245, 163, 79, 0.4)',
                padding: '12px 20px',
                borderRadius: '24px',
                color: '#FFF8F1',
                fontSize: '17px',
                fontWeight: 700,
              }}
            >
              <Github size={20} color={AppColors.primaryLight} />
              <span>github.com/evolucaomente27-bot/NekoCast---App</span>
            </div>

            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                gap: '8px',
                backgroundColor: 'rgba(38, 23, 17, 0.95)',
                border: '1.5px solid rgba(76, 175, 80, 0.5)',
                padding: '12px 20px',
                borderRadius: '24px',
                color: AppColors.success,
                fontSize: '17px',
                fontWeight: 700,
              }}
            >
              <ShieldCheck size={20} />
              <span>Android • Windows • Web • Linux • iOS</span>
            </div>
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
