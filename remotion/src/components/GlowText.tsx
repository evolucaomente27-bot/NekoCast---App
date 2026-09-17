import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { AppColors } from '../theme/colors';

interface GlowTextProps {
  text: string;
  highlightText?: string;
  delay?: number;
  fontSize?: number | string;
  style?: React.CSSProperties;
}

export const GlowText: React.FC<GlowTextProps> = ({
  text,
  highlightText,
  delay = 0,
  fontSize = '48px',
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const progress = spring({
    frame: frame - delay,
    fps,
    config: {
      damping: 15,
      stiffness: 120,
    },
  });

  const opacity = interpolate(frame - delay, [0, 8], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const translateY = interpolate(progress, [0, 1], [30, 0]);

  return (
    <div
      style={{
        transform: `translateY(${translateY}px)`,
        opacity,
        fontSize,
        fontWeight: 800,
        color: AppColors.textPrimary,
        lineHeight: 1.15,
        letterSpacing: '-0.5px',
        ...style,
      }}
    >
      {text}{' '}
      {highlightText && (
        <span
          style={{
            background: 'linear-gradient(90deg, #F5A34F 0%, #FFC36B 50%, #E67B2D 100%)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            textShadow: '0 0 40px rgba(245, 163, 79, 0.4)',
            display: 'inline-block',
          }}
        >
          {highlightText}
        </span>
      )}
    </div>
  );
};
