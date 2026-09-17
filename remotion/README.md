# 🎬 NekoCast Promo Video (Remotion)

Projeto de vídeo programático profissional do **NekoCast** desenvolvido em **Remotion** (React + TypeScript).

---

## 📺 Cenas do Vídeo

1. **Abertura & Branding (0s - 6s)**: Apresentação da marca, logo NekoCast com iluminação âmbar pulsante e destaques de abertura.
2. **Catálogo & Streaming (6s - 13s)**: Mockup da interface inicial, navegação por tendências, lançamentos e integração multi-fontes.
3. **Player de Vídeo & AniSkip (13s - 20s)**: Demonstração do player com suporte a resolução 1080p e a funcionalidade **AniSkip** (pular abertura/encerramento).
4. **Leitor de Mangás (20s - 27s)**: Mockup mobile do leitor de mangás integrado (MangaDex), suporte a modo Webtoon contínuo e modo noturno.
5. **Downloads Offline & Multiplataforma (27s - 34s)**: Gerenciador de downloads offline com suporte a pausa/retomada e ecossistema Flutter (Android, Windows, Linux, Web, iOS, macOS).
6. **Encerramento & Call to Action (34s - 40s)**: Chamada final para download, repositório GitHub e selo open-source.

---

## 🚀 Como Executar

Entre na pasta `remotion`:

```bash
cd remotion
```

### 1. Pré-visualização Interativa no Remotion Studio

Abre o player do Remotion no navegador com linha do tempo, controle de frames e inspeção de cenas em tempo real:

```bash
npm start
# ou
npm run preview
```

### 2. Renderizar Vídeo Completo em MP4 (Full HD 1080p)

Renderiza o vídeo promocional completo em alta definição para a pasta `remotion/out/nekocast_promo_landscape.mp4`:

```bash
npm run build
```

### 3. Capturar Frames Estáticos (Stills)

Para capturar um frame de alta resolução de qualquer segundo do vídeo:

```bash
npm run still
```

---

## 📁 Estrutura de Arquivos

```text
remotion/
├── public/              # Logos e imagens estáticas
│   ├── logo.png
│   └── neko.png
├── src/
│   ├── components/      # Componentes visuais reutilizáveis
│   │   ├── Background.tsx
│   │   ├── Badge.tsx
│   │   ├── DeviceMockup.tsx
│   │   └── GlowText.tsx
│   ├── scenes/          # Cenas do vídeo
│   │   ├── IntroScene.tsx
│   │   ├── CatalogScene.tsx
│   │   ├── PlayerScene.tsx
│   │   ├── MangaScene.tsx
│   │   ├── DownloadsScene.tsx
│   │   └── OutroScene.tsx
│   ├── theme/           # Cores oficiais do AppColors
│   │   └── colors.ts
│   ├── MainVideo.tsx    # Orquestração das cenas em sequência
│   ├── Root.tsx         # Registro de composições Remotion
│   └── index.ts         # Ponto de entrada
├── remotion.config.ts
├── package.json
└── tsconfig.json
```
