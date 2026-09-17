import fs from 'fs';
import path from 'path';
import https from 'https';

const API_KEY = 'sk-fish-1lAWfnmYZWJYGANgVNmUh6ty_lAyTroSJyCnfPLeIoY';

async function generateFishAudioTTS(text, outputPath, voiceReferenceId = null) {
  return new Promise((resolve, reject) => {
    const payload = {
      text: text,
      format: 'mp3',
      mp3_bitrate: 192,
      latency: 'normal',
      normalize: true,
    };

    if (voiceReferenceId) {
      payload.reference_id = voiceReferenceId;
    }

    const postData = JSON.stringify(payload);

    const options = {
      hostname: 'api.fish.audio',
      path: '/v1/tts',
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_KEY}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
      },
    };

    const req = https.request(options, (res) => {
      if (res.statusCode !== 200) {
        let errData = '';
        res.on('data', (chunk) => (errData += chunk));
        res.on('end', () => reject(new Error(`Fish Audio API Error ${res.statusCode}: ${errData}`)));
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
  const publicDir = path.resolve('public');
  if (!fs.existsSync(publicDir)) {
    fs.mkdirSync(publicDir, { recursive: true });
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

  console.log('Generating voiceover with Fish Audio for Landscape (40s)...');
  const landscapePath = path.join(publicDir, 'voiceover_landscape.mp3');
  await generateFishAudioTTS(textLandscape, landscapePath);
  console.log(`Saved: ${landscapePath}`);

  console.log('Generating voiceover with Fish Audio for YouTube Shorts (28s)...');
  const shortsPath = path.join(publicDir, 'voiceover_shorts.mp3');
  await generateFishAudioTTS(textShorts, shortsPath);
  console.log(`Saved: ${shortsPath}`);

  console.log('All Fish Audio voiceovers generated successfully!');
}

main().catch((err) => {
  console.error('Fatal error with Fish Audio API:', err);
});
