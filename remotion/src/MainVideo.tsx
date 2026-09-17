import React from 'react';
import { AbsoluteFill, Series, Audio, staticFile, interpolate } from 'remotion';
import { IntroScene } from './scenes/IntroScene';
import { CatalogScene } from './scenes/CatalogScene';
import { PlayerScene } from './scenes/PlayerScene';
import { MangaScene } from './scenes/MangaScene';
import { DownloadsScene } from './scenes/DownloadsScene';
import { OutroScene } from './scenes/OutroScene';

export const MainVideo: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: '#120B08' }}>
      {/* Música de Fundo (Synthwave Anime) */}
      <Audio
        src={staticFile('background_music.wav')}
        volume={(f) =>
          interpolate(f, [0, 30, 1140, 1200], [0, 0.3, 0.3, 0], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          })
        }
      />

      {/* Trilha de Locução Neural AI */}
      <Audio src={staticFile('voiceover_landscape.mp3')} volume={1} />

      <Series>
        {/* Cena 1: Intro & Revelação da Marca (0s - 6s) */}
        <Series.Sequence durationInFrames={180}>
          <IntroScene />
        </Series.Sequence>

        {/* Cena 2: Catálogo & Descoberta (6s - 13s) */}
        <Series.Sequence durationInFrames={210}>
          <CatalogScene />
        </Series.Sequence>

        {/* Cena 3: Player de Vídeo & AniSkip (13s - 20s) */}
        <Series.Sequence durationInFrames={210}>
          <PlayerScene />
        </Series.Sequence>

        {/* Cena 4: Leitor de Mangás (20s - 27s) */}
        <Series.Sequence durationInFrames={210}>
          <MangaScene />
        </Series.Sequence>

        {/* Cena 5: Downloads Offline & Multiplataforma (27s - 34s) */}
        <Series.Sequence durationInFrames={210}>
          <DownloadsScene />
        </Series.Sequence>

        {/* Cena 6: Encerramento & Call to Action (34s - 40s) */}
        <Series.Sequence durationInFrames={180}>
          <OutroScene />
        </Series.Sequence>
      </Series>
    </AbsoluteFill>
  );
};
