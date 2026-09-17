import { useState, useEffect } from 'react';
import type { AnimeItem } from '../../services/animeApi';
import {
  getSeasonAnimes,
  getTopAnimes,
  getAnimesByGenre,
  searchAnimes,
} from '../../services/animeApi';
import { isFavorite, toggleFavorite } from '../../services/favoritesService';
import {
  Search,
  Star,
  Play,
  Heart,
  X,
  Tv,
  Loader2,
} from 'lucide-react';

const GENRE_MAP: Record<string, number> = {
  action: 1,
  romance: 22,
  fantasy: 10,
  comedy: 4,
};

export default function AnimeExplorer() {
  const [tab, setTab] = useState<'season' | 'top' | 'action' | 'romance' | 'fantasy'>('season');
  const [query, setQuery] = useState('');
  const [animes, setAnimes] = useState<AnimeItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedAnime, setSelectedAnime] = useState<AnimeItem | null>(null);
  const [playTrailer, setPlayTrailer] = useState(false);
  const [, setFavUpdateTrigger] = useState(0);

  // Carrega lista inicial ou ao trocar de aba
  useEffect(() => {
    let isCancelled = false;

    async function loadCategory() {
      if (query.trim().length > 0) return; // Se tiver busca ativa, prioriza a busca
      setLoading(true);
      let data: AnimeItem[] = [];

      try {
        if (tab === 'season') {
          data = await getSeasonAnimes();
        } else if (tab === 'top') {
          data = await getTopAnimes();
        } else if (GENRE_MAP[tab]) {
          data = await getAnimesByGenre(GENRE_MAP[tab]);
        }
      } catch (err) {
        console.error(err);
      }

      if (!isCancelled) {
        setAnimes(data);
        setLoading(false);
      }
    }

    loadCategory();

    return () => {
      isCancelled = true;
    };
  }, [tab, query]);

  // Busca debounced
  useEffect(() => {
    if (!query.trim()) return;

    setLoading(true);
    const timer = setTimeout(async () => {
      try {
        const results = await searchAnimes(query);
        setAnimes(results);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [query]);

  const handleToggleFav = (anime: AnimeItem, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    toggleFavorite({
      id: anime.mal_id,
      title: anime.title,
      imageUrl: anime.images.jpg.large_image_url || anime.images.jpg.image_url,
      type: 'anime',
      scoreOrTag: anime.score ? `⭐ ${anime.score}` : 'Anime',
    });
    setFavUpdateTrigger((v) => v + 1);
  };

  return (
    <div className="w-full">
      {/* Barra de Busca e Categorias */}
      <div className="flex flex-col md:flex-row items-center justify-between gap-4 mb-8">
        {/* Input de Busca */}
        <div className="relative w-full md:w-96">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Pesquisar animes (ex: Solo Leveling, Bleach)..."
            className="w-full pl-11 pr-10 py-2.5 rounded-full bg-white/5 border border-white/10 text-white placeholder-white/40 text-sm focus:outline-none focus:border-[#FF6B1A] transition-colors"
          />
          {query && (
            <button
              onClick={() => setQuery('')}
              className="absolute right-3 top-1/2 -translate-y-1/2 text-white/40 hover:text-white"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Abas */}
        {!query && (
          <div className="flex items-center gap-1 sm:gap-2 overflow-x-auto w-full md:w-auto pb-2 md:pb-0 scrollbar-none">
            <button
              onClick={() => setTab('season')}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all ${
                tab === 'season'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'bg-white/5 text-white/70 hover:bg-white/10'
              }`}
            >
              🔥 Temporada
            </button>
            <button
              onClick={() => setTab('top')}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all ${
                tab === 'top'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'bg-white/5 text-white/70 hover:bg-white/10'
              }`}
            >
              ⭐ Mais Populares
            </button>
            <button
              onClick={() => setTab('action')}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all ${
                tab === 'action'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'bg-white/5 text-white/70 hover:bg-white/10'
              }`}
            >
              ⚔️ Ação
            </button>
            <button
              onClick={() => setTab('romance')}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all ${
                tab === 'romance'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'bg-white/5 text-white/70 hover:bg-white/10'
              }`}
            >
              🌸 Romance
            </button>
            <button
              onClick={() => setTab('fantasy')}
              className={`px-4 py-2 rounded-full text-xs sm:text-sm font-medium whitespace-nowrap transition-all ${
                tab === 'fantasy'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'bg-white/5 text-white/70 hover:bg-white/10'
              }`}
            >
              ✨ Fantasia
            </button>
          </div>
        )}
      </div>

      {/* Grid de Animes */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3 text-white/60">
          <Loader2 className="w-8 h-8 animate-spin text-[#FF6B1A]" />
          <p className="text-sm">Carregando catálogo de animes...</p>
        </div>
      ) : animes.length === 0 ? (
        <div className="text-center py-20 bg-white/5 rounded-2xl border border-white/5">
          <Tv className="w-12 h-12 text-white/20 mx-auto mb-3" />
          <p className="text-white font-medium">Nenhum anime encontrado.</p>
          <p className="text-white/40 text-sm mt-1">Tente pesquisar com outro termo.</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
          {animes.map((anime) => {
            const hasFav = isFavorite(anime.mal_id, 'anime');
            return (
              <div
                key={anime.mal_id}
                onClick={() => {
                  setSelectedAnime(anime);
                  setPlayTrailer(false);
                }}
                className="group relative bg-[#141414] rounded-xl overflow-hidden border border-white/5 hover:border-[#FF6B1A]/50 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl hover:shadow-[#FF6B1A]/10 cursor-pointer flex flex-col"
              >
                {/* Imagem de Capa */}
                <div className="relative aspect-[3/4] w-full overflow-hidden bg-black/40">
                  <img
                    src={anime.images.webp?.image_url || anime.images.jpg.image_url}
                    alt={anime.title}
                    loading="lazy"
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/20" />

                  {/* Badge de Nota */}
                  {anime.score && (
                    <div className="absolute top-2 left-2 flex items-center gap-1 bg-black/70 backdrop-blur-md px-2 py-0.5 rounded-md border border-white/10 text-xs font-semibold text-yellow-400">
                      <Star className="w-3 h-3 fill-yellow-400 text-yellow-400" />
                      {anime.score.toFixed(1)}
                    </div>
                  )}

                  {/* Botão de Favoritar Rápido */}
                  <button
                    onClick={(e) => handleToggleFav(anime, e)}
                    className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 backdrop-blur-md border border-white/10 hover:scale-110 transition-transform"
                  >
                    <Heart
                      className={`w-3.5 h-3.5 ${
                        hasFav ? 'fill-[#FF6B1A] text-[#FF6B1A]' : 'text-white/70'
                      }`}
                    />
                  </button>

                  {/* Botão Play Hover */}
                  <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-black/40">
                    <div className="w-10 h-10 rounded-full bg-[#FF6B1A] flex items-center justify-center text-white shadow-lg shadow-[#FF6B1A]/40 scale-90 group-hover:scale-100 transition-transform">
                      <Play className="w-5 h-5 fill-white ml-0.5" />
                    </div>
                  </div>

                  {/* Episódios / Status */}
                  <div className="absolute bottom-2 left-2 right-2 flex items-center justify-between text-[11px] text-white/80">
                    <span>{anime.episodes ? `${anime.episodes} eps` : 'Em exibição'}</span>
                    <span>{anime.year || ''}</span>
                  </div>
                </div>

                {/* Título e Gênero */}
                <div className="p-3 flex flex-col flex-1 justify-between">
                  <h3 className="font-semibold text-xs sm:text-sm text-white line-clamp-2 leading-tight group-hover:text-[#FF6B1A] transition-colors">
                    {anime.title}
                  </h3>
                  <div className="mt-2 flex flex-wrap gap-1">
                    {anime.genres?.slice(0, 2).map((g) => (
                      <span
                        key={g.mal_id}
                        className="text-[10px] bg-white/5 text-white/50 px-1.5 py-0.5 rounded"
                      >
                        {g.name}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal de Detalhes do Anime */}
      {selectedAnime && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
          <div className="relative w-full max-w-3xl max-h-[90vh] bg-[#121212] border border-white/10 rounded-2xl overflow-hidden shadow-2xl flex flex-col">
            {/* Header Modal com Botão Fechar */}
            <button
              onClick={() => setSelectedAnime(null)}
              className="absolute top-4 right-4 z-20 p-2 rounded-full bg-black/60 text-white/80 hover:text-white hover:bg-black/90 transition-colors"
            >
              <X className="w-5 h-5" />
            </button>

            {/* Conteúdo com Scroll */}
            <div className="overflow-y-auto p-6 sm:p-8 space-y-6">
              {/* Player do Trailer ou Poster */}
              {playTrailer && selectedAnime.trailer?.youtube_id ? (
                <div className="relative aspect-video w-full rounded-xl overflow-hidden bg-black shadow-lg border border-white/10">
                  <iframe
                    src={`https://www.youtube-nocookie.com/embed/${selectedAnime.trailer.youtube_id}?autoplay=1`}
                    title={`${selectedAnime.title} Trailer`}
                    className="w-full h-full"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                    allowFullScreen
                  />
                </div>
              ) : (
                <div className="relative flex flex-col sm:flex-row gap-6 items-start">
                  <img
                    src={
                      selectedAnime.images.webp?.large_image_url ||
                      selectedAnime.images.jpg.large_image_url ||
                      selectedAnime.images.jpg.image_url
                    }
                    alt={selectedAnime.title}
                    className="w-40 sm:w-48 rounded-xl object-cover shadow-2xl border border-white/10 shrink-0 mx-auto sm:mx-0"
                  />

                  <div className="flex-1 space-y-3">
                    <div className="flex items-center gap-2 flex-wrap">
                      {selectedAnime.score && (
                        <span className="flex items-center gap-1 bg-yellow-500/20 text-yellow-400 px-2.5 py-1 rounded-full text-xs font-bold border border-yellow-500/30">
                          <Star className="w-3.5 h-3.5 fill-yellow-400" />
                          {selectedAnime.score.toFixed(1)} / 10
                        </span>
                      )}
                      {selectedAnime.status && (
                        <span className="bg-white/10 text-white/80 px-2.5 py-1 rounded-full text-xs">
                          {selectedAnime.status}
                        </span>
                      )}
                      {selectedAnime.episodes && (
                        <span className="bg-white/10 text-white/80 px-2.5 py-1 rounded-full text-xs">
                          {selectedAnime.episodes} Episódios
                        </span>
                      )}
                    </div>

                    <h2 className="text-xl sm:text-2xl font-bold text-white leading-tight">
                      {selectedAnime.title}
                    </h2>
                    {selectedAnime.title_english && (
                      <p className="text-sm text-white/50">{selectedAnime.title_english}</p>
                    )}

                    <div className="flex flex-wrap gap-1.5 pt-1">
                      {selectedAnime.genres?.map((g) => (
                        <span
                          key={g.mal_id}
                          className="text-xs bg-[#FF6B1A]/10 text-[#FF6B1A] border border-[#FF6B1A]/20 px-2.5 py-0.5 rounded-full"
                        >
                          {g.name}
                        </span>
                      ))}
                    </div>

                    {/* Ações */}
                    <div className="flex items-center gap-3 pt-4">
                      {selectedAnime.trailer?.youtube_id && (
                        <button
                          onClick={() => setPlayTrailer(true)}
                          className="flex items-center gap-2 px-5 py-2.5 rounded-full bg-[#FF6B1A] text-white font-semibold text-sm hover:bg-[#ff7b33] transition-colors shadow-lg shadow-[#FF6B1A]/30"
                        >
                          <Play className="w-4 h-4 fill-white" />
                          Assistir Trailer HD
                        </button>
                      )}

                      <button
                        onClick={() => handleToggleFav(selectedAnime)}
                        className={`flex items-center gap-2 px-4 py-2.5 rounded-full border text-sm font-medium transition-colors ${
                          isFavorite(selectedAnime.mal_id, 'anime')
                            ? 'bg-rose-500/20 border-rose-500/50 text-rose-400'
                            : 'bg-white/5 border-white/10 text-white hover:bg-white/10'
                        }`}
                      >
                        <Heart
                          className={`w-4 h-4 ${
                            isFavorite(selectedAnime.mal_id, 'anime') ? 'fill-rose-400' : ''
                          }`}
                        />
                        {isFavorite(selectedAnime.mal_id, 'anime') ? 'Salvo na Lista' : 'Salvar Anime'}
                      </button>
                    </div>
                  </div>
                </div>
              )}

              {/* Sinopse */}
              <div className="space-y-2 pt-2 border-t border-white/10">
                <h4 className="text-sm font-semibold text-white/90">Sinopse</h4>
                <p className="text-sm text-white/70 leading-relaxed max-h-48 overflow-y-auto pr-2">
                  {selectedAnime.synopsis || 'Sem sinopse disponível em texto para este anime.'}
                </p>
              </div>

              {/* Informações Adicionais */}
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 pt-2 text-xs text-white/60">
                <div>
                  <span className="block text-white/30">Estúdio</span>
                  <span className="text-white/80">
                    {selectedAnime.studios?.map((s) => s.name).join(', ') || 'N/D'}
                  </span>
                </div>
                <div>
                  <span className="block text-white/30">Exibição</span>
                  <span className="text-white/80">{selectedAnime.aired?.string || 'N/D'}</span>
                </div>
                <div>
                  <span className="block text-white/30">Classificação</span>
                  <span className="text-white/80">{selectedAnime.rating || 'Livre'}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
