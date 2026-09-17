import fs from 'fs';
import path from 'path';
import https from 'https';

const API_KEY = 'sk_aa40520af8b3ccdaaa5c34ed47ced090ff1b26d6a356302d';

// Popular ElevenLabs Default Voice IDs
const VOICES = {
  adam: 'pNInz6obpgDQGcFmaJgB', // Deep, warm, narrator
  antoni: 'ErXwobaYiN019PkySvjV', // Clear, versatile
  rachel: '21m00Tcm4TlvDq8ikWAM', // Calm, young female
  brian: 'nPczCjzI2devNBz1zQrb', // Expressive narrator
  roger: 'CwhRBWXzGAHq8TQ4Fs17', // Confident, energetic
};

// Function to generate TTS audio directly
async function generateTTS(voiceId, text, outputPath) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      text,
      model_id: 'eleven_multilingual_v2',
      voice_settings: {
        stability: 0.45,
        similarity_boost: 0.8,
        style: 0.2,
        use_speaker_boost: true,
      },
    });

    const options = {
      hostname: 'api.elevenlabs.io',
      path: `/v1/text-to-speech/${voiceId}`,
      method: 'POST',
      headers: {
        'xi-api-key': API_KEY,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errData = '';
        res.on('data', (d) => (errData += d));
        res.on('end', () => reject(new Error(`API Error ${res.statusCode}: ${errData}`)));
        return;
      }

      const fileStream = fs.createWriteStream(outputPath);
      res.pipe(fileStream);
      fileStream.on('finish', () => {
        fileStream.close();
        resolve(outputPath);
      });
    });

    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function main() {
  const outDir = path.resolve('public');
  if (!fs.existsSync(outDir)) {
    fs.mkdirSync(outDir, { recursive: true });
  }

  // 1. Script para o Vídeo Landscape (40s)
  const textLandscape = `Apresentamos o NekoCast: a sua central definitiva de animes e mangás na palma da mão!
Explore um catálogo ilimitado com lançamentos da temporada, recomendações populares e integração com as melhores fontes da web.
Assista em Full HD com um player ultra responsivo e o recurso exclusivo AniSkip, que detecta e pula aberturas automaticamente.
Gosta de leitura? O leitor de mangás integrado oferece navegação vertical fluida e sincronização com o MangaDex.
Baixe episódios para assistir offline em qualquer lugar. Disponível para Android, Windows, Web, Linux e iOS.
Livre de anúncios invasivos e totalmente gratuito. Baixe o NekoCast hoje mesmo e transforme sua experiência otaku!`;

  // 2. Script para o YouTube Shorts (28s)
  const textShorts = `Cansado de apps travando e cheios de anúncios toda vez que você quer assistir anime? Conheça o NekoCast!
Milhares de animes em alta definição, múltiplas fontes e temporadas atualizadas em tempo real.
E o melhor: com o AniSkip, você pula aberturas e encerramentos com apenas um toque!
Além disso, leia seus mangás favoritos e baixe episódios completos para assistir offline onde quiser.
Cem por cento gratuito e de código aberto. Baixe o NekoCast agora pelo link na descrição!`;

  console.log('Generating voiceover for Landscape (40s)...');
  const landscapePath = path.join(outDir, 'voiceover_landscape.mp3');
  await generateTTS(VOICES.roger, textLandscape, landscapePath);
  console.log(`Saved: ${landscapePath}`);

  console.log('Generating voiceover for YouTube Shorts (28s)...');
  const shortsPath = path.join(outDir, 'voiceover_shorts.mp3');
  await generateTTS(VOICES.roger, textShorts, shortsPath);
  console.log(`Saved: ${shortsPath}`);

  console.log('All voiceovers generated successfully!');
}

main().catch(err => {
  console.error('Fatal error:', err);
});
