import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { AppColors } from '../theme/colors';

interface DeviceMockupProps {
  type?: 'phone' | 'desktop';
  delay?: number;
  rotation?: number;
  scale?: number;
  children: React.ReactNode;
  style?: React.CSSProperties;
}

export const DeviceMockup: React.FC<DeviceMockupProps> = ({
  type = 'desktop',
  delay = 0,
  rotation = 0,
  scale = 1,
  children,
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = spring({
    frame: frame - delay,
    fps,
    config: {
      damping: 16,
      stiffness: 90,
      mass: 0.9,
    },
  });

  const enterScale = interpolate(progress, [0, 1], [0.8, 1]);
  const translateY = interpolate(progress, [0, 1], [60, 0]);
  const opacity = interpolate(frame - delay, [0, 12], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Floating idle motion
  const floatY = Math.sin((frame - delay) / 25) * 6;
  const floatRotate = Math.cos((frame - delay) / 35) * 0.8;

  if (type === 'phone') {
    return (
      <div
        style={{
          width: '340px',
          height: '660px',
          borderRadius: '44px',
          background: '#1A100B',
          padding: '12px',
          boxShadow: `
            0 25px 60px -15px rgba(0, 0, 0, 0.9),
            0 0 40px rgba(230, 123, 45, 0.25),
            inset 0 0 0 2px rgba(245, 163, 79, 0.3)
          `,
          transform: `translateY(${translateY + floatY}px) scale(${enterScale * scale}) rotate(${rotation + floatRotate}deg)`,
          opacity,
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
          overflow: 'hidden',
          ...style,
        }}
      >
        {/* Dynamic Island / Notch */}
        <div
          style={{
            position: 'absolute',
            top: '16px',
            left: '50%',
            transform: 'translateX(-50%)',
            width: '100px',
            height: '24px',
            backgroundColor: '#0A0604',
            borderRadius: '16px',
            zIndex: 30,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '8px',
          }}
        >
          <div
            style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              backgroundColor: '#1E120B',
            }}
          />
          <div
            style={{
              width: '6px',
              height: '6px',
              borderRadius: '50%',
              backgroundColor: '#0F2B48',
            }}
          />
        </div>

        {/* Screen Content Container */}
        <div
          style={{
            flex: 1,
            borderRadius: '34px',
            backgroundColor: AppColors.background,
            overflow: 'hidden',
            position: 'relative',
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          {children}
        </div>
      </div>
    );
  }

  // Desktop Cinema Window
  return (
    <div
      style={{
        width: '960px',
        height: '560px',
        borderRadius: '24px',
        background: 'linear-gradient(180deg, #241712 0%, #150D09 100%)',
        padding: '2px',
        boxShadow: `
          0 35px 80px -20px rgba(0, 0, 0, 0.95),
          0 0 60px rgba(230, 123, 45, 0.22),
          0 0 0 1px rgba(245, 163, 79, 0.3)
        `,
        transform: `translateY(${translateY + floatY}px) scale(${enterScale * scale}) rotate(${rotation + floatRotate * 0.5}deg)`,
        opacity,
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        ...style,
      }}
    >
      {/* Window Title Bar */}
      <div
        style={{
          height: '42px',
          backgroundColor: '#1B120D',
          borderBottom: '1px solid rgba(230, 123, 45, 0.15)',
          display: 'flex',
          alignItems: 'center',
          padding: '0 18px',
          gap: '8px',
          borderTopLeftRadius: '22px',
          borderTopRightRadius: '22px',
        }}
      >
        <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#FF5F56' }} />
        <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#FFBD2E' }} />
        <div style={{ width: '12px', height: '12px', borderRadius: '50%', backgroundColor: '#27C93F' }} />

        <div
          style={{
            marginLeft: 'auto',
            marginRight: 'auto',
            fontSize: '13px',
            color: AppColors.textTertiary,
            fontWeight: 600,
            letterSpacing: '0.5px',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
          }}
        >
          <span style={{ color: AppColors.primaryLight }}>NekoCast</span> — Anime & Manga Hub
        </div>
      </div>

      {/* Screen Content Container */}
      <div
        style={{
          flex: 1,
          backgroundColor: AppColors.background,
          overflow: 'hidden',
          position: 'relative',
          borderBottomLeftRadius: '22px',
          borderBottomRightRadius: '22px',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {children}
      </div>
    </div>
  );
};
