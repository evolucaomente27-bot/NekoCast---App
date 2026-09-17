import React from 'react';
import { AbsoluteFill, Series, Audio, staticFile, interpolate } from 'remotion';
import { VerticalHookScene } from './scenes_vertical/VerticalHookScene';
import { VerticalCatalogScene } from './scenes_vertical/VerticalCatalogScene';
import { VerticalPlayerScene } from './scenes_vertical/VerticalPlayerScene';
import { VerticalMangaDownloadScene } from './scenes_vertical/VerticalMangaDownloadScene';
import { VerticalOutroScene } from './scenes_vertical/VerticalOutroScene';

export const VerticalShortsVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: '#120B08' }}>
      {/* Música de Fundo (Synthwave Anime) */}
      <Audio
        src={staticFile('background_music_shorts.wav')}
        volume={(f) =>
          interpolate(f, [0, 20, 800, 840], [0, 0.3, 0.3, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })
        }
      />

      {/* Trilha de Locução Neural AI */}
      <Audio src={staticFile('voiceover_shorts.mp3')} volume={1} />

      <Series>
        {/* Cena 1: Hook Dinâmico (0s - 5s / 150 frames) */}
        <Series.Sequence durationInFrames={150}>
          <VerticalHookScene />
        </Series.Sequence>

        {/* Cena 2: Catálogo & Streaming HD (5s - 11s / 180 frames) */}
        <Series.Sequence durationInFrames={180}>
          <VerticalCatalogScene />
        </Series.Sequence>

        {/* Cena 3: AniSkip & Player (11s - 17s / 180 frames) */}
        <Series.Sequence durationInFrames={180}>
          <VerticalPlayerScene />
        </Series.Sequence>

        {/* Cena 4: Mangás & Downloads Offline (17s - 23s / 180 frames) */}
        <Series.Sequence durationInFrames={180}>
          <VerticalMangaDownloadScene />
        </Series.Sequence>

        {/* Cena 5: Call to Action & Download (23s - 28s / 150 frames) */}
        <Series.Sequence durationInFrames={150}>
          <VerticalOutroScene />
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};
