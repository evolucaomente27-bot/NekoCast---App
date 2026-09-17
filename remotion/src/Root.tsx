import React from 'react';
import { Composition } from 'remotion';
import { MainVideo } from './MainVideo';
import { VerticalShortsVideo } from './VerticalShortsVideo';
import { IntroScene } from './scenes/IntroScene';
import { CatalogScene } from './scenes/CatalogScene';
import { PlayerScene } from './scenes/PlayerScene';
import { MangaScene } from './scenes/MangaScene';
import { DownloadsScene } from './scenes/DownloadsScene';
import { OutroScene } from './scenes/OutroScene';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* 1. Vídeo Promocional Landscape 16:9 (1920x1080 - 40s) */}
      <Composition
        id="NekoCastPromoLandscape"
        component={MainVideo}
        durationInFrames={1200}
        fps={30}
        width={1920}
        height={1080}
      />

      {/* 2. Vídeo Vertical YouTube Shorts / TikTok / Reels 9:16 (1080x1920 - 28s) */}
      <Composition
        id="NekoCastShorts"
        component={VerticalShortsVideo}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1920}
      />

      {/* Cenas Individuais Landscape para Pré-visualização Rápida no Studio */}
      <Composition
        id="Scene1-Intro"
        component={IntroScene}
        durationInFrames={180}
        fps={30}
        width={1920}
        height={1080}
      />

      <Composition
        id="Scene2-Catalog"
        component={CatalogScene}
        durationInFrames={210}
        fps={30}
        width={1920}
        height={1080}
      />

      <Composition
        id="Scene3-Player"
        component={PlayerScene}
        durationInFrames={210}
        fps={30}
        width={1920}
        height={1080}
      />

      <Composition
        id="Scene4-Manga"
        component={MangaScene}
        durationInFrames={210}
        fps={30}
        width={1920}
        height={1080}
      />

      <Composition
        id="Scene5-Downloads"
        component={DownloadsScene}
        durationInFrames={210}
        fps={30}
        width={1920}
        height={1080}
      />

      <Composition
        id="Scene6-Outro"
        component={OutroScene}
        durationInFrames={180}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
