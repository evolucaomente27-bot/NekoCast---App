export interface MangaItem {
  id: string;
  title: string;
  description: string;
  coverUrl: string;
  status: string;
  year?: number;
  tags: string[];
}

export interface ChapterItem {
  id: string;
  chapter: string;
  title: string;
  language: string;
  publishedAt: string;
  pages: number;
}

const MANGADEX_BASE = 'https://api.mangadex.org';

export async function getPopularManga(): Promise<MangaItem[]> {
  try {
    const url = `${MANGADEX_BASE}/manga?limit=24&order[followedCount]=desc&includes[]=cover_art&contentRating[]=safe&contentRating[]=suggestive`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Falha ao buscar mangás populares');
    const json = await res.json();
    return formatMangaList(json.data || []);
  } catch (error) {
    console.warn('Erro ao buscar mangás MangaDex:', error);
    return [];
  }
}

export async function searchManga(query: string): Promise<MangaItem[]> {
  if (!query.trim()) return [];
  try {
    const encoded = encodeURIComponent(query.trim());
    const url = `${MANGADEX_BASE}/manga?title=${encoded}&limit=24&includes[]=cover_art&contentRating[]=safe&contentRating[]=suggestive`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Falha na busca de mangás');
    const json = await res.json();
    return formatMangaList(json.data || []);
  } catch (error) {
    console.warn('Erro ao pesquisar mangás MangaDex:', error);
    return [];
  }
}

export async function getMangaChapters(mangaId: string): Promise<ChapterItem[]> {
  try {
    const url = `${MANGADEX_BASE}/manga/${mangaId}/feed?limit=100&translatedLanguage[]=pt-br&translatedLanguage[]=en&order[chapter]=desc`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Falha ao obter capítulos');
    const json = await res.json();
    const data = json.data || [];

    return data.map((item: any) => {
      const attrs = item.attributes || {};
      return {
        id: item.id,
        chapter: attrs.chapter || 'Extra',
        title: attrs.title || (attrs.chapter ? `Capítulo ${attrs.chapter}` : 'Especial'),
        language: attrs.translatedLanguage || 'unknown',
        publishedAt: attrs.publishAt || attrs.createdAt,
        pages: attrs.pages || 0,
      };
    });
  } catch (error) {
    console.warn('Erro ao obter capítulos:', error);
    return [];
  }
}

export async function getChapterPages(chapterId: string): Promise<string[]> {
  try {
    const url = `${MANGADEX_BASE}/at-home/server/${chapterId}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error('Falha ao obter páginas do capítulo');
    const json = await res.json();
    const baseUrl = json.baseUrl;
    const hash = json.chapter?.hash;
    const files: string[] = json.chapter?.data || [];

    return files.map((file) => `${baseUrl}/data/${hash}/${file}`);
  } catch (error) {
    console.warn('Erro ao obter páginas MangaDex:', error);
    return [];
  }
}

function formatMangaList(data: any[]): MangaItem[] {
  return data.map((item) => {
    const attrs = item.attributes || {};
    const titleObj = attrs.title || {};
    const title =
      titleObj['pt-br'] ||
      titleObj['en'] ||
      titleObj['ja-ro'] ||
      Object.values(titleObj)[0] ||
      'Mangá sem título';

    const descObj = attrs.description || {};
    const description =
      descObj['pt-br'] ||
      descObj['en'] ||
      Object.values(descObj)[0] ||
      'Sem descrição disponível.';

    // Extrair capa
    const coverRel = (item.relationships || []).find((r: any) => r.type === 'cover_art');
    const fileName = coverRel?.attributes?.fileName;
    const coverUrl = fileName
      ? `https://uploads.mangadex.org/covers/${item.id}/${fileName}.512.jpg`
      : 'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80';

    const tags = (attrs.tags || [])
      .map((t: any) => t.attributes?.name?.en)
      .filter(Boolean)
      .slice(0, 4);

    return {
      id: item.id,
      title,
      description,
      coverUrl,
      status: attrs.status || 'ongoing',
      year: attrs.year,
      tags,
    };
  });
}
