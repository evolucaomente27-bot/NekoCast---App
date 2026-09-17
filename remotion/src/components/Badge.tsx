import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { AppColors } from '../theme/colors';

interface BadgeProps {
  icon?: React.ReactNode;
  label: string;
  sublabel?: string;
  delay?: number;
  variant?: 'primary' | 'accent' | 'secondary' | 'glass';
  style?: React.CSSProperties;
}

export const Badge: React.FC<BadgeProps> = ({
  icon,
  label,
  sublabel,
  delay = 0,
  variant = 'glass',
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = spring({
    frame: frame - delay,
    fps,
    config: {
      damping: 14,
      stiffness: 110,
      mass: 0.8,
    },
  });

  const opacity = interpolate(frame - delay, [0, 10], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const translateY = interpolate(progress, [0, 1], [25, 0]);
  const scale = interpolate(progress, [0, 1], [0.9, 1]);

  let bg = 'rgba(38, 23, 17, 0.95)';
  let border = '1.5px solid rgba(245, 163, 79, 0.45)';
  let textColor = '#FFF8F1';
  let glow = '0 10px 30px rgba(0, 0, 0, 0.6), 0 0 20px rgba(230, 123, 45, 0.2)';

  if (variant === 'primary') {
    bg = 'linear-gradient(135deg, rgba(245, 163, 79, 0.95), rgba(230, 123, 45, 0.95))';
    border = '2px solid #FFE3AF';
    textColor = '#120B08';
    glow = '0 10px 35px rgba(230, 123, 45, 0.55)';
  } else if (variant === 'accent') {
    bg = 'linear-gradient(135deg, rgba(45, 28, 18, 0.95), rgba(60, 35, 20, 0.95))';
    border = '1.5px solid rgba(255, 179, 0, 0.8)';
    textColor = '#FFE3AF';
    glow = '0 0 25px rgba(255, 179, 0, 0.35)';
  }

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '14px',
        padding: '14px 22px',
        borderRadius: '16px',
        background: bg,
        backdropFilter: 'blur(16px)',
        border,
        boxShadow: glow,
        color: textColor,
        transform: `translateY(${translateY}px) scale(${scale})`,
        opacity,
        ...style,
      }}
    >
      {icon && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            width: '42px',
            height: '42px',
            borderRadius: '12px',
            backgroundColor: variant === 'primary' ? 'rgba(18, 11, 8, 0.15)' : 'rgba(230, 123, 45, 0.25)',
            border: variant === 'primary' ? 'none' : '1px solid rgba(245, 163, 79, 0.4)',
            color: variant === 'primary' ? '#120B08' : AppColors.primaryLight,
            flexShrink: 0,
          }}
        >
          {icon}
        </div>
      )}
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        <span
          style={{
            fontWeight: 800,
            fontSize: '18px',
            letterSpacing: '0.2px',
            lineHeight: 1.25,
            color: textColor,
          }}
        >
          {label}
        </span>
        {sublabel && (
          <span
            style={{
              fontSize: '13px',
              color: variant === 'primary' ? 'rgba(18,11,8,0.85)' : '#D8C5B7',
              fontWeight: 500,
              marginTop: '3px',
              lineHeight: 1.3,
            }}
          >
            {sublabel}
          </span>
        )}
      </div>
    </div>
  );
};
