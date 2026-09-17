const express = require('express');
const cors = require('cors');
const axios = require('axios');
const cheerio = require('cheerio');
const path = require('path');
const fs = require('fs');
const https = require('https');
const { addExtra } = require('puppeteer-extra');
const puppeteerCore = require('puppeteer-core');
const puppeteer = addExtra(puppeteerCore);
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const httpsAgent = new https.Agent({ rejectUnauthorized: false });

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware CORS
app.use(cors({ origin: '*' }));
app.use(express.json());

const USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

// Global Puppeteer Browser
let globalBrowser = null;

const os = require('os');
const isWindows = os.platform() === 'win32';

let linuxChromePath = undefined;
if (!isWindows) {
  const possiblePaths = [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/usr/local/bin/chromium'
  ];
  for (const p of possiblePaths) {
    if (fs.existsSync(p)) {
      linuxChromePath = p;
      break;
    }
  }
}

async function getPuppeteerHtml(url) {
  if (!globalBrowser) {
    globalBrowser = await puppeteer.launch({
      headless: true,
      executablePath: isWindows ? 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe' : linuxChromePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
        '--disable-gpu'
      ]
    });
  }
  
  const page = await globalBrowser.newPage();
  await page.setUserAgent(USER_AGENT);
  
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 15000 });
    
    // Wait for the Cloudflare challenge to pass and the content to load
    // AnimesOnline uses 'article.item', AnimesOrion uses 'article'
    await page.waitForSelector('article', { timeout: 15000 }).catch(() => {});
    
    const html = await page.content();
    await page.close();
    return html;
  } catch (error) {
    await page.close();
    throw error;
  }
}

// Candidatos de caminho para os arquivos do Frontend Web (Flutter Web)
const possiblePaths = [
  path.join(__dirname, 'public'),
  path.join(process.cwd(), 'server/public'),
  path.join(process.cwd(), 'public'),
  path.join(__dirname, '../build/web'),
  path.join(process.cwd(), 'build/web')
];

let webBuildPath = possiblePaths.find(p => fs.existsSync(path.join(p, 'index.html'))) || possiblePaths[0];

// Servir arquivos estáticos do Frontend (Flutter Web)
if (fs.existsSync(path.join(webBuildPath, 'index.html'))) {
  app.use(express.static(webBuildPath));
  console.log(`[NekoCast FullApp] Servindo Frontend Web de: ${webBuildPath}`);
}

// Endpoint de saúde do servidor e consumo de RAM (Limite: 1024MB)
app.get('/health', (req, res) => {
  const memoryUsage = process.memoryUsage();
  const rssMB = (memoryUsage.rss / (1024 * 1024)).toFixed(2);
  const heapMB = (memoryUsage.heapUsed / (1024 * 1024)).toFixed(2);

  res.json({
    status: 'ok',
    mode: 'Full-Stack (Frontend + Backend)',
    uptimeSeconds: Math.floor(process.uptime()),
    ramUsageRSS: `${rssMB} MB`,
    ramHeapUsed: `${heapMB} MB`,
    ramLimit: '1024 MB (1 GB)'
  });
});

// Proxy CORS universal para mídias e streams
app.get('/api/proxy', async (req, res) => {
  const targetUrl = req.query.url;

  if (!targetUrl) {
    return res.status(400).json({ error: 'Parâmetro url é obrigatório' });
  }

  try {
    const response = await axios({
      method: 'get',
      url: targetUrl,
      headers: {
        'User-Agent': USER_AGENT,
        'Referer': req.query.referer || targetUrl
      },
      responseType: 'stream',
      timeout: 15000
    });

    res.set({
      'Access-Control-Allow-Origin': '*',
      'Content-Type': response.headers['content-type'] || 'application/octet-stream'
    });

    response.data.pipe(res);
  } catch (error) {
    res.status(500).json({
      error: 'Falha no proxy',
      message: error.message
    });
  }
});

// ==========================================
// API Busca e Vídeo AnimeFire (animefire.plus / animefire.io)
// ==========================================
app.get('/api/animefire/search', async (req, res) => {
  const query = req.query.q;
  if (!query) {
    return res.status(400).json({ error: 'Parâmetro q é obrigatório' });
  }

  try {
    const results = [];
    const encodedQuery = encodeURIComponent(query.trim());

    // A versão atual do AnimeFire renderiza a busca no cliente e expõe os
    // dados no endpoint JSON. Use-o antes dos fallbacks HTML antigos.
    const apiResponse = await axios.get(
      `https://api.animefire.io/animes/pesquisar?q=${encodedQuery}`,
      {
        headers: {
          'User-Agent': USER_AGENT,
          'Accept': 'application/json',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8'
        },
        httpsAgent,
        timeout: 8000
      }
    );

    if (apiResponse.status === 200 && Array.isArray(apiResponse.data?.data)) {
      for (const item of apiResponse.data.data) {
        if (!item?.id || !item?.title) continue;
        results.push({
          id: String(item.id),
          name: String(item.title),
          url: `https://animefire.io/anime/${item.id}`,
          source: 'animeFire',
          imageUrl: item.poster_src || null
        });
      }
    }

    if (results.length > 0) {
      return res.json({ count: results.length, query, results });
    }

    const slug = encodeURIComponent(query.trim().toLowerCase().replace(/\s+/g, '-'));

    const urls = [
      `https://animefire.io/animes/pesquisar?q=${encodedQuery}`,
      `https://animefire.io/pesquisar/${slug}`,
      `https://animefire.plus/pesquisar/${slug}`
    ];

    for (const url of urls) {
      const response = await axios.get(url, {
        headers: {
          'User-Agent': USER_AGENT,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8'
        },
        httpsAgent,
        timeout: 8000
      });

      const $ = cheerio.load(response.data);
      $('a[href^="/anime/"], a[href*="/anime/"], a[href*="/animes/"], .row.ml-1.mr-1 a, .card_ani .ani_name a').each((_, el) => {
        const rawUrl = ($(el).attr('href') || '').trim();
        if (!rawUrl || !/\/animes?\//i.test(rawUrl)) return;

        const card = $(el).closest('article, .card_ani, .row.ml-1.mr-1');
        const name = (card.find('h3').first().text() || $(el).find('h3').first().text() || $(el).text())
          .replace(/\s+/g, ' ')
          .trim();
        if (!name) return;

        const fullUrl = new URL(rawUrl, 'https://animefire.io').href;
        if (results.some(r => r.url === fullUrl)) return;

        const img = card.find('img').first().attr('data-src') ||
          card.find('img').first().attr('data-lazy-src') ||
          card.find('img').first().attr('src') ||
          $(el).find('img').first().attr('src');
        const id = new URL(fullUrl).pathname.split('/').filter(Boolean).pop();

        results.push({
          id,
          name,
          url: fullUrl,
          source: 'animeFire',
          imageUrl: img || null
        });
      });

      if (results.length > 0 || url === urls[urls.length - 1]) break;
    }

    res.json({ count: results.length, query, results });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar no AnimeFire', message: error.message });
  }
});

app.get('/api/animefire/info', async (req, res) => {
  const animeUrl = req.query.url || (req.query.id ? `https://animefire.plus/animes/${req.query.id}` : null);
  if (!animeUrl) return res.status(400).json({ error: 'Parâmetro url ou id é obrigatório' });

  try {
    const response = await axios.get(animeUrl, {
      headers: { 'User-Agent': USER_AGENT },
      httpsAgent,
      timeout: 8000
    });
    const $ = cheerio.load(response.data);
    const episodes = [];

    $('a.lEp, .div_video_list a, a[href*="/animes/"]').each((_, el) => {
      const href = $(el).attr('href');
      const title = $(el).text().replace(/\s+/g, ' ').trim();
      if (href && /\/\d+$/.test(href) && !episodes.some(e => e.url === href)) {
        const epNum = href.split('/').filter(Boolean).pop();
        episodes.push({
          id: epNum,
          number: epNum,
          title: title || `Episódio ${epNum}`,
          url: href.startsWith('http') ? href : `https://animefire.plus${href.startsWith('/') ? '' : '/'}${href}`
        });
      }
    });

    res.json({ animeUrl, count: episodes.length, episodes });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar episódios no AnimeFire', message: error.message });
  }
});

app.get('/api/animefire/watch', async (req, res) => {
  const episodeUrl = req.query.url;
  if (!episodeUrl) return res.status(400).json({ error: 'Parâmetro url é obrigatório' });

  try {
    const response = await axios.get(episodeUrl, {
      headers: { 'User-Agent': USER_AGENT },
      httpsAgent,
      timeout: 8000
    });
    const $ = cheerio.load(response.data);
    let videoSrc = $('video#my-video').attr('data-video-src') || $('video').attr('data-video-src');

    if (!videoSrc) {
      const match = response.data.match(/data-video-src=["']([^"']+)["']/);
      if (match) videoSrc = match[1];
    }

    if (!videoSrc) {
      return res.status(404).json({ error: 'Player de vídeo não encontrado na página' });
    }

    const videoRes = await axios.get(videoSrc, {
      headers: {
        'User-Agent': USER_AGENT,
        'Referer': episodeUrl,
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest'
      },
      httpsAgent,
      timeout: 8000
    });

    const list = videoRes.data?.data || [];
    const sources = list.map(item => ({
      url: item.src,
      quality: item.label || 'auto',
      headers: { 'Referer': 'https://animefire.plus/' }
    }));

    res.json({ episodeUrl, sources });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao extrair vídeo do AnimeFire', message: error.message });
  }
});

// ==========================================
// API Busca e Vídeo AnimesDigital (animesdigital.org)
// ==========================================
app.get('/api/animesdigital/search', async (req, res) => {
  const query = req.query.q;
  if (!query) return res.status(400).json({ error: 'Parâmetro q é obrigatório' });

  try {
    const url = `https://animesdigital.org/?s=${encodeURIComponent(query)}`;
    const response = await axios.get(url, {
      httpsAgent,
      headers: { 'User-Agent': USER_AGENT },
      timeout: 8000
    });
    const $ = cheerio.load(response.data);
    const results = [];

    $('a[href*="/anime/"]').each((_, el) => {
      const name = $(el).text().trim();
      const rawUrl = $(el).attr('href') || '';
      const img = $(el).find('img').attr('src') || $(el).closest('.item, article, div').find('img').attr('src');
      const id = rawUrl.split('/').filter(Boolean).pop();

      if (name && rawUrl && !results.some(r => r.url === rawUrl)) {
        results.push({
          id,
          name,
          url: rawUrl,
          imageUrl: img || null,
          source: 'animesDigital'
        });
      }
    });

    res.json({ count: results.length, query, results });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar no AnimesDigital', message: error.message });
  }
});

app.get('/api/animesdigital/info', async (req, res) => {
  const id = req.query.id;
  const animeUrl = req.query.url || `https://animesdigital.org/anime/a/${id}`;
  if (!id && !req.query.url) return res.status(400).json({ error: 'Parâmetro id ou url é obrigatório' });

  try {
    const response = await axios.get(animeUrl, {
      httpsAgent,
      headers: { 'User-Agent': USER_AGENT },
      timeout: 8000
    });
    const $ = cheerio.load(response.data);
    const episodes = [];

    $('a[href*="/video/"]').each((_, el) => {
      const epUrl = $(el).attr('href');
      const epTitle = $(el).text().replace(/\s+/g, ' ').trim();
      if (epUrl && !episodes.some(e => e.url === epUrl)) {
        const epNumMatch = epTitle.match(/Epis[óo]dio\s*(\d+)/i) || epTitle.match(/(\d+)/);
        const epNum = epNumMatch ? epNumMatch[1] : `${episodes.length + 1}`;
        const epId = epUrl.split('/').filter(Boolean).pop();
        episodes.push({
          id: epId,
          number: epNum,
          title: epTitle,
          url: epUrl
        });
      }
    });

    res.json({ id, animeUrl, count: episodes.length, episodes });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar episódios no AnimesDigital', message: error.message });
  }
});

app.get('/api/animesdigital/watch', async (req, res) => {
  const episodeId = req.query.episodeId;
  const episodeUrl = req.query.url || `https://animesdigital.org/video/a/${episodeId}/`;
  if (!episodeId && !req.query.url) return res.status(400).json({ error: 'Parâmetro episodeId ou url é obrigatório' });

  try {
    const response = await axios.get(episodeUrl, {
      httpsAgent,
      headers: { 'User-Agent': USER_AGENT, 'Referer': 'https://animesdigital.org/' },
      timeout: 8000
    });
    const $ = cheerio.load(response.data);
    const iframes = $('iframe').map((_, el) => $(el).attr('src')).get();
    const sources = [];

    for (const iframe of iframes) {
      if (iframe.includes('videohls.php?d=')) {
        const m3u8Match = iframe.match(/videohls\.php\?d=([^&]+)/);
        if (m3u8Match) {
          const streamUrl = decodeURIComponent(m3u8Match[1]);
          sources.push({
            url: streamUrl,
            quality: 'auto (HLS)',
            isM3U8: true,
            headers: { 'Referer': 'https://api.anivideo.net/' }
          });
        }
      } else if (iframe.includes('blogger.com')) {
        sources.push({ url: iframe, quality: 'Blogger', isIframe: true });
      } else if (iframe) {
        sources.push({ url: iframe, quality: 'embed' });
      }
    }

    res.json({ episodeUrl, sources });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar vídeo no AnimesDigital', message: error.message });
  }
});

// API Busca AllAnime
app.get('/api/allanime/search', async (req, res) => {
  const query = req.query.q;
  if (!query) {
    return res.status(400).json({ error: 'Parâmetro q é obrigatório' });
  }

  try {
    const gqlQuery = `
      query($search: SearchInput, $limit: Int, $page: Int, $translationType: VaildTranslationTypeEnumType, $countryOrigin: VaildCountryOriginEnumType) {
        shows(search: $search, limit: $limit, page: $page, translationType: $translationType, countryOrigin: $countryOrigin) {
          edges {
            _id
            name
            englishName
            availableEpisodes
            thumbnail
          }
        }
      }
    `;

    const variables = {
      search: { allowAdult: false, allowUnknown: false, query },
      limit: 20,
      page: 1,
      translationType: 'sub',
      countryOrigin: 'ALL'
    };

    const response = await axios.get('https://api.allanime.day/api', {
      params: {
        variables: JSON.stringify(variables),
        query: gqlQuery
      },
      headers: {
        'User-Agent': USER_AGENT,
        'Referer': 'https://allanime.to'
      },
      httpsAgent,
      timeout: 8000
    });

    const edges = response.data?.data?.shows?.edges || [];
    const results = edges.map(show => ({
      id: show._id,
      name: show.name || show.englishName,
      englishName: show.englishName,
      episodes: show.availableEpisodes,
      thumbnail: show.thumbnail,
      source: 'allAnime'
    }));

    res.json({ count: results.length, query, results });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar no AllAnime', message: error.message });
  }
});

// ==========================================
// API Busca AnimesOnline (animesonlinecc.to)
// ==========================================
app.get('/api/animesonline/search', async (req, res) => {
  const query = req.query.q;
  if (!query) return res.status(400).json({ error: 'Parâmetro q é obrigatório' });

  try {
    const url = `https://animesonlinecc.to/search/${encodeURIComponent(query)}`;
    let html;
    try {
      const resp = await axios.get(url, { headers: { 'User-Agent': USER_AGENT }, httpsAgent, timeout: 6000 });
      html = resp.data;
    } catch (e) {
      html = await getPuppeteerHtml(url);
    }

    const $ = cheerio.load(html);
    const results = [];

    $('article.item').each((_, el) => {
      const name = $(el).find('h3 a').text().trim();
      const rawUrl = $(el).find('h3 a').attr('href') || '';
      const img = $(el).find('img').attr('src');
      let id = rawUrl.split('/').filter(Boolean).pop();

      if (name && rawUrl) {
        results.push({ id, name, url: rawUrl, imageUrl: img || null, source: 'animesOnline' });
      }
    });

    res.json({ count: results.length, query, results });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar no AnimesOnline', message: error.message });
  }
});

app.get('/api/animesonline/info', async (req, res) => {
  const id = req.query.id;
  if (!id) return res.status(400).json({ error: 'Parâmetro id é obrigatório' });

  try {
    const url = `https://animesonlinecc.to/anime/${id}/`;
    let html;
    try {
      const resp = await axios.get(url, { headers: { 'User-Agent': USER_AGENT }, httpsAgent, timeout: 6000 });
      html = resp.data;
    } catch (e) {
      html = await getPuppeteerHtml(url);
    }

    const $ = cheerio.load(html);
    const episodes = [];

    $('ul.episodios li').each((_, el) => {
      const epRawUrl = $(el).find('a').attr('href');
      const epId = epRawUrl ? epRawUrl.split('/').filter(Boolean).pop() : '';
      const numStr = $(el).find('.numerando').text().trim() || '';
      const num = numStr.split('-').pop().trim();
      const title = $(el).find('.episodiotitle a').text().trim();

      if (epId) {
        episodes.push({ id: epId, number: num, title, url: epRawUrl });
      }
    });

    res.json({ id, episodes });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar info no AnimesOnline', message: error.message });
  }
});

app.get('/api/animesonline/watch', async (req, res) => {
  const epId = req.query.episodeId;
  if (!epId) return res.status(400).json({ error: 'Parâmetro episodeId é obrigatório' });

  try {
    const url = `https://animesonlinecc.to/episodio/${epId}/`;
    let html;
    try {
      const resp = await axios.get(url, { headers: { 'User-Agent': USER_AGENT }, httpsAgent, timeout: 6000 });
      html = resp.data;
    } catch (e) {
      html = await getPuppeteerHtml(url);
    }
    
    const $ = cheerio.load(html);
    const sources = [];
    
    $('iframe').each((_, el) => {
      const src = $(el).attr('src');
      if (src) sources.push({ url: src, quality: 'auto' });
    });

    $('ul#playeroptionsul li').each((_, el) => {
      const type = $(el).attr('data-type');
      const post = $(el).attr('data-post');
      const nume = $(el).attr('data-nume');
      if (type && post && nume) {
         sources.push({ url: `https://animesonlinecc.to/wp-admin/admin-ajax.php?action=doo_player_ajax&post=${post}&nume=${nume}&type=${type}`, quality: 'auto' });
      }
    });
    
    res.json({ sources });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar vídeo no AnimesOnline', message: error.message });
  }
});

// ==========================================
// API Busca AnimesOrion (animesorion.cc)
// ==========================================
app.get('/api/animesorion/search', async (req, res) => {
  const query = req.query.q;
  if (!query) return res.status(400).json({ error: 'Parâmetro q é obrigatório' });

  try {
    const url = `https://animesorion.cc/?s=${encodeURIComponent(query)}`;
    const html = await getPuppeteerHtml(url);
    const $ = cheerio.load(html);
    const results = [];

    $('article').each((_, el) => {
      const name = $(el).find('h3 a').text().trim() || $(el).find('h2.Title').text().trim();
      const rawUrl = $(el).find('a').first().attr('href') || '';
      const img = $(el).find('img').attr('src');
      let id = rawUrl.split('/').filter(Boolean).pop();

      if (name && rawUrl) {
        results.push({ id, name, url: rawUrl, imageUrl: img || null, source: 'animesOrion' });
      }
    });

    res.json({ count: results.length, query, results });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar no AnimesOrion', message: error.message });
  }
});

app.get('/api/animesorion/info', async (req, res) => {
  const id = req.query.id;
  if (!id) return res.status(400).json({ error: 'Parâmetro id é obrigatório' });

  try {
    const url = `https://animesorion.cc/animes/${id}/`;
    const html = await getPuppeteerHtml(url);
    const $ = cheerio.load(html);
    const episodes = [];

    $('ul.episodios li').each((_, el) => {
      const epRawUrl = $(el).find('a').attr('href');
      const epId = epRawUrl ? epRawUrl.split('/').filter(Boolean).pop() : '';
      const numStr = $(el).find('.numerando').text().trim() || '';
      const num = numStr.split('-').pop().trim();
      const title = $(el).find('.episodiotitle a').text().trim();

      if (epId) {
        episodes.push({ id: epId, number: num, title });
      }
    });

    res.json({ id, episodes });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar info no AnimesOrion', message: error.message });
  }
});

app.get('/api/animesorion/watch', async (req, res) => {
  const epId = req.query.episodeId;
  if (!epId) return res.status(400).json({ error: 'Parâmetro episodeId é obrigatório' });

  try {
    const url = `https://animesorion.cc/episodios/${epId}/`;
    const html = await getPuppeteerHtml(url);
    
    const $ = cheerio.load(html);
    const sources = [];
    
    $('ul#playeroptionsul li').each((_, el) => {
      const type = $(el).attr('data-type');
      const post = $(el).attr('data-post');
      const nume = $(el).attr('data-nume');
      if (type && post && nume) {
         sources.push({ url: `https://animesorion.cc/wp-admin/admin-ajax.php?action=doo_player_ajax&post=${post}&nume=${nume}&type=${type}`, quality: 'auto' });
      }
    });
    
    res.json({ sources });
  } catch (error) {
    res.status(500).json({ error: 'Erro ao buscar vídeo no AnimesOrion', message: error.message });
  }
});

// Integration with @consumet/extensions
let ANIME, META;
try {
  const consumet = require('@consumet/extensions');
  ANIME = consumet.ANIME;
  META = consumet.META;
  console.log('[Consumet Extensions] Módulo carregado com sucesso!');
} catch (e) {
  console.warn('[Consumet Extensions] Erro ao carregar o módulo:', e.message);
}

const providerInstances = {};
if (META && META.Anilist) {
  providerInstances['anilist'] = new META.Anilist();
}
if (ANIME) {
  if (ANIME.Hianime) providerInstances['hianime'] = new ANIME.Hianime();
  if (ANIME.Hianime) providerInstances['zoro'] = new ANIME.Hianime();
  if (ANIME.Hianime) providerInstances['gogoanime'] = new ANIME.Hianime();
  if (ANIME.AnimePahe) providerInstances['animepahe'] = new ANIME.AnimePahe();
  if (ANIME.AnimeKai) providerInstances['animekai'] = new ANIME.AnimeKai();
  if (ANIME.KickAssAnime) providerInstances['kickassanime'] = new ANIME.KickAssAnime();
  if (ANIME.AnimeSama) providerInstances['animesama'] = new ANIME.AnimeSama();
}

function getConsumetProvider(name) {
  const key = (name || 'anilist').toLowerCase();
  return providerInstances[key] || providerInstances['anilist'] || providerInstances['hianime'];
}

// Endpoint de Busca Consumet (/anime/:provider/:query ou /api/consumet/search)
app.get(['/anime/:provider/:query', '/api/consumet/search'], async (req, res) => {
  const providerName = req.params.provider || req.query.provider || 'anilist';
  const query = req.params.query || req.query.q;

  if (!query) {
    return res.status(400).json({ error: 'Parâmetro de busca não fornecido' });
  }

  try {
    let provider = getConsumetProvider(providerName);
    let data;
    try {
      data = await provider.search(query);
      if (!data || !data.results || data.results.length === 0) {
        if (providerInstances['anilist'] && providerName !== 'anilist') {
          console.log(`[Consumet Fallback] Provedor "${providerName}" não retornou resultados. Usando Anilist...`);
          data = await providerInstances['anilist'].search(query);
        }
      }
    } catch (err) {
      console.warn(`[Consumet Warning] Provedor "${providerName}" falhou (${err.message}). Usando Anilist como fallback...`);
      if (providerInstances['anilist'] && providerName !== 'anilist') {
        data = await providerInstances['anilist'].search(query);
      } else {
        throw err;
      }
    }
    res.json(data);
  } catch (error) {
    console.error(`[Consumet Search Error] ${providerName} - ${query}:`, error.message);
    res.status(500).json({ error: 'Erro na busca do Consumet', message: error.message });
  }
});

// Endpoint de Informações/Episódios Consumet (/anime/:provider/info/:id ou /api/consumet/info)
app.get(['/anime/:provider/info/:id(*)', '/api/consumet/info'], async (req, res) => {
  const providerName = req.params.provider || req.query.provider || 'anilist';
  const animeId = req.params.id || req.query.id;

  if (!animeId) {
    return res.status(400).json({ error: 'ID do anime não fornecido' });
  }

  try {
    let provider = getConsumetProvider(providerName);
    let data;
    try {
      data = await provider.fetchAnimeInfo(animeId);
      if (!data || !data.episodes || data.episodes.length === 0) {
        if (providerInstances['anilist'] && providerName !== 'anilist') {
          console.log(`[Consumet Info Fallback] Provedor "${providerName}" não retornou episódios para ${animeId}. Usando Anilist...`);
          data = await providerInstances['anilist'].fetchAnimeInfo(animeId);
        }
      }
    } catch (err) {
      console.warn(`[Consumet Info Warning] Provedor "${providerName}" falhou para ID ${animeId} (${err.message}). Usando Anilist...`);
      if (providerInstances['anilist'] && providerName !== 'anilist') {
        data = await providerInstances['anilist'].fetchAnimeInfo(animeId);
      } else {
        throw err;
      }
    }
    res.json(data);
  } catch (error) {
    console.error(`[Consumet Info Error] ${providerName} - ${animeId}:`, error.message);
    res.status(500).json({ error: 'Erro ao buscar detalhes do Consumet', message: error.message });
  }
});

// Endpoint de Fontes de Vídeo Consumet (/anime/:provider/watch/:episodeId(*)', '/api/consumet/watch']
app.get(['/anime/:provider/watch/:episodeId(*)', '/api/consumet/watch'], async (req, res) => {
  const providerName = req.params.provider || req.query.provider || 'anilist';
  const episodeId = req.params.episodeId || req.query.episodeId;

  if (!episodeId) {
    return res.status(400).json({ error: 'ID do episódio não fornecido' });
  }

  try {
    let provider = getConsumetProvider(providerName);
    let data;
    try {
      data = await provider.fetchEpisodeSources(episodeId);
      if (!data || !data.sources || data.sources.length === 0) {
        if (providerInstances['anilist'] && providerName !== 'anilist') {
          console.log(`[Consumet Watch Fallback] Provedor "${providerName}" não retornou fontes para ${episodeId}. Usando Anilist...`);
          data = await providerInstances['anilist'].fetchEpisodeSources(episodeId);
        }
      }
    } catch (err) {
      console.warn(`[Consumet Watch Warning] Provedor "${providerName}" falhou para EP ${episodeId} (${err.message}). Usando Anilist...`);
      if (providerInstances['anilist'] && providerName !== 'anilist') {
        data = await providerInstances['anilist'].fetchEpisodeSources(episodeId);
      } else {
        throw err;
      }
    }
    res.json(data);
  } catch (error) {
    console.error(`[Consumet Watch Error] ${providerName} - ${episodeId}:`, error.message);
    res.status(500).json({ error: 'Erro ao buscar fontes de vídeo do Consumet', message: error.message });
  }
});

// SPA Fallback para o Flutter Web (Redireciona qualquer rota web para index.html)
app.get('*', (req, res) => {
  const activePath = possiblePaths.find(p => fs.existsSync(path.join(p, 'index.html')));
  if (activePath) {
    res.sendFile(path.join(activePath, 'index.html'));
  } else {
    res.json({
      name: 'NekoCast FullApp API',
      status: 'online',
      message: 'Frontend web não encontrado. Certifique-se de que a pasta public ou build/web está incluída.'
    });
  }
});

// Inicializar Servidor
app.listen(PORT, () => {
  console.log(`[NekoCast FullApp] Servidor Full-Stack rodando na porta ${PORT}`);
  console.log(`[Discloud] Configurado com sucesso. Limite RAM: 1024MB.`);
});
