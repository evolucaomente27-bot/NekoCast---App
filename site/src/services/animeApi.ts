export interface AnimeItem {
  mal_id: number;
  title: string;
  title_english?: string;
  title_japanese?: string;
  images: {
    jpg: {
      image_url: string;
      small_image_url?: string;
      large_image_url?: string;
    };
    webp?: {
      image_url: string;
      small_image_url?: string;
      large_image_url?: string;
    };
  };
  trailer?: {
    youtube_id?: string;
    url?: string;
    embed_url?: string;
  };
  synopsis?: string;
  score?: number;
  scored_by?: number;
  rank?: number;
  popularity?: number;
  episodes?: number;
  status?: string;
  aired?: {
    string?: string;
  };
  rating?: string;
  genres?: Array<{ mal_id: number; name: string }>;
  studios?: Array<{ mal_id: number; name: string }>;
  year?: number;
}

const JIKAN_BASE = 'https://api.jikan.moe/v4';

// Cache em memória para otimizar taxa de requisição
const cache = new Map<string, { data: any; timestamp: number }>();
const CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutos

async function fetchJikan<T>(endpoint: string): Promise<T> {
  const cached = cache.get(endpoint);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
    return cached.data as T;
  }

  const url = `${JIKAN_BASE}${endpoint}`;
  const response = await fetch(url, {
    headers: {
      Accept: 'application/json',
    },
  });

  if (!response.ok) {
    if (response.status === 429) {
      // Se atingir rate limit da Jikan, aguarda 1.2s e tenta novamente
      await new Promise((resolve) => setTimeout(resolve, 1200));
      const retryResponse = await fetch(url);
      if (!retryResponse.ok) {
        throw new Error(`Jikan API error ${retryResponse.status}`);
      }
      const retryJson = await retryResponse.json();
      cache.set(endpoint, { data: retryJson.data, timestamp: Date.now() });
      return retryJson.data as T;
    }
    throw new Error(`Jikan API error ${response.status}`);
  }

  const json = await response.json();
  cache.set(endpoint, { data: json.data, timestamp: Date.now() });
  return json.data as T;
}

export async function getSeasonAnimes(): Promise<AnimeItem[]> {
  try {
    return await fetchJikan<AnimeItem[]>('/seasons/now?limit=24');
  } catch (error) {
    console.warn('Erro ao buscar animes da temporada:', error);
    return [];
  }
}

export async function getTopAnimes(): Promise<AnimeItem[]> {
  try {
    return await fetchJikan<AnimeItem[]>('/top/anime?filter=bypopularity&limit=24');
  } catch (error) {
    console.warn('Erro ao buscar top animes:', error);
    return [];
  }
}

export async function getAnimesByGenre(genreId: number): Promise<AnimeItem[]> {
  try {
    return await fetchJikan<AnimeItem[]>(`/anime?genres=${genreId}&order_by=score&sort=desc&limit=24`);
  } catch (error) {
    console.warn(`Erro ao buscar animes do gênero ${genreId}:`, error);
    return [];
  }
}

export async function searchAnimes(query: string): Promise<AnimeItem[]> {
  if (!query.trim()) return [];
  try {
    const encoded = encodeURIComponent(query.trim());
    return await fetchJikan<AnimeItem[]>(`/anime?q=${encoded}&limit=24&sfw=true`);
  } catch (error) {
    console.warn('Erro na busca de animes:', error);
    return [];
  }
}

export async function getAnimeDetails(id: number): Promise<AnimeItem | null> {
  try {
    return await fetchJikan<AnimeItem>(`/anime/${id}/full`);
  } catch (error) {
    console.warn(`Erro ao buscar detalhes do anime ${id}:`, error);
    return null;
  }
}
