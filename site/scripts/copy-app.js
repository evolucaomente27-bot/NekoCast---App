import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const distDir = path.resolve(__dirname, '../dist');
const targetDistApp = path.join(distDir, 'app');

// Candidatos de caminho para a pasta compilada do Flutter Web
const candidateWebPaths = [
  path.resolve(__dirname, '../../build/web'),
  path.resolve(process.cwd(), 'build/web'),
  path.resolve(process.cwd(), '../build/web'),
];

function copyFolderSync(from, to) {
  if (!fs.existsSync(to)) {
    fs.mkdirSync(to, { recursive: true });
  }

  for (const element of fs.readdirSync(from)) {
    const srcPath = path.join(from, element);
    const destPath = path.join(to, element);
    const stat = fs.lstatSync(srcPath);

    if (stat.isDirectory()) {
      copyFolderSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// 1. Criação do arquivo .nojekyll (obrigatório para GitHub Pages não ignorar pastas com underline)
try {
  if (fs.existsSync(distDir)) {
    fs.writeFileSync(path.join(distDir, '.nojekyll'), '');
    console.log('[post-build] Arquivo .nojekyll criado para GitHub Pages.');
  }
} catch (e) {
  console.warn('[post-build] Aviso ao criar .nojekyll:', e.message);
}

// 2. Criação do arquivo 404.html (para roteamento SPA no GitHub Pages)
try {
  const indexHtmlPath = path.join(distDir, 'index.html');
  const notFoundHtmlPath = path.join(distDir, '404.html');
  if (fs.existsSync(indexHtmlPath)) {
    fs.copyFileSync(indexHtmlPath, notFoundHtmlPath);
    console.log('[post-build] Arquivo 404.html criado a partir do index.html para GitHub Pages.');
  }
} catch (e) {
  console.warn('[post-build] Aviso ao criar 404.html:', e.message);
}

// 3. Cópia do Flutter Web (se disponível)
let copied = false;
for (const cand of candidateWebPaths) {
  if (fs.existsSync(path.join(cand, 'index.html'))) {
    try {
      console.log(`[copy-app] Copiando Flutter Web de '${cand}' para '${targetDistApp}'...`);
      copyFolderSync(cand, targetDistApp);
      console.log(`[copy-app] Flutter Web copiado com sucesso para /app!`);
      copied = true;
      break;
    } catch (err) {
      console.warn(`[copy-app] Aviso: Falha ao copiar Flutter Web:`, err.message);
    }
  }
}

if (!copied) {
  console.log(`[copy-app] Informação: Build do Flutter Web não encontrado (ambiente remoto padrão sem Flutter). O site funcionará perfeitamente em modo 100% serverless.`);
}
