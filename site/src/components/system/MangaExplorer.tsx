import { useState, useEffect } from 'react';
import type { MangaItem, ChapterItem } from '../../services/mangaApi';
import {
  getPopularManga,
  searchManga,
  getMangaChapters,
  getChapterPages,
} from '../../services/mangaApi';
import { isFavorite, toggleFavorite } from '../../services/favoritesService';
import {
  Search,
  BookOpen,
  Heart,
  X,
  ChevronLeft,
  ChevronRight,
  Loader2,
} from 'lucide-react';

export default function MangaExplorer() {
  const [query, setQuery] = useState('');
  const [mangas, setMangas] = useState<MangaItem[]>([]);
  const [loading, setLoading] = useState(true);

  // Modal de Capítulos
  const [selectedManga, setSelectedManga] = useState<MangaItem | null>(null);
  const [chapters, setChapters] = useState<ChapterItem[]>([]);
  const [loadingChapters, setLoadingChapters] = useState(false);

  // Leitor de Mangá
  const [activeChapter, setActiveChapter] = useState<ChapterItem | null>(null);
  const [pages, setPages] = useState<string[]>([]);
  const [currentPageIndex, setCurrentPageIndex] = useState(0);
  const [loadingPages, setLoadingPages] = useState(false);
  const [, setFavTrigger] = useState(0);

  // Carrega mangás populares
  useEffect(() => {
    let isCancelled = false;

    async function load() {
      if (query.trim().length > 0) return;
      setLoading(true);
      try {
        const data = await getPopularManga();
        if (!isCancelled) setMangas(data);
      } catch (err) {
        console.error(err);
      } finally {
        if (!isCancelled) setLoading(false);
      }
    }

    load();

    return () => {
      isCancelled = true;
    };
  }, [query]);

  // Busca debounced
  useEffect(() => {
    if (!query.trim()) return;

    setLoading(true);
    const timer = setTimeout(async () => {
      try {
        const results = await searchManga(query);
        setMangas(results);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }, 450);

    return () => clearTimeout(timer);
  }, [query]);

  // Abre modal do mangá e carrega capítulos
  const handleOpenManga = async (manga: MangaItem) => {
    setSelectedManga(manga);
    setLoadingChapters(true);
    try {
      const chList = await getMangaChapters(manga.id);
      setChapters(chList);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingChapters(false);
    }
  };

  // Abre leitor de capítulo
  const handleOpenReader = async (chapter: ChapterItem) => {
    setActiveChapter(chapter);
    setLoadingPages(true);
    setCurrentPageIndex(0);
    try {
      const pageList = await getChapterPages(chapter.id);
      setPages(pageList);
    } catch (err) {
      console.error(err);
    } finally {
      setLoadingPages(false);
    }
  };

  const handleToggleFav = (manga: MangaItem, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    toggleFavorite({
      id: manga.id,
      title: manga.title,
      imageUrl: manga.coverUrl,
      type: 'manga',
      scoreOrTag: manga.tags[0] || 'Mangá',
    });
    setFavTrigger((v) => v + 1);
  };

  return (
    <div className="w-full">
      {/* Busca */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-8">
        <div className="relative w-full sm:w-96">
          <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-white/40" />
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Pesquisar mangás no MangaDex (ex: One Piece, Berserk)..."
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

        <div className="text-xs text-white/50 flex items-center gap-2">
          <BookOpen className="w-4 h-4 text-[#FF6B1A]" />
          <span>Catálogo direto via MangaDex API (Serverless)</span>
        </div>
      </div>

      {/* Grid de Mangás */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-3 text-white/60">
          <Loader2 className="w-8 h-8 animate-spin text-[#FF6B1A]" />
          <p className="text-sm">Buscando catálogo no MangaDex...</p>
        </div>
      ) : mangas.length === 0 ? (
        <div className="text-center py-20 bg-white/5 rounded-2xl border border-white/5">
          <BookOpen className="w-12 h-12 text-white/20 mx-auto mb-3" />
          <p className="text-white font-medium">Nenhum mangá encontrado.</p>
          <p className="text-white/40 text-sm mt-1">Tente pesquisar por outro título.</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
          {mangas.map((manga) => {
            const hasFav = isFavorite(manga.id, 'manga');
            return (
              <div
                key={manga.id}
                onClick={() => handleOpenManga(manga)}
                className="group relative bg-[#141414] rounded-xl overflow-hidden border border-white/5 hover:border-[#FF6B1A]/50 transition-all duration-300 hover:-translate-y-1 hover:shadow-xl hover:shadow-[#FF6B1A]/10 cursor-pointer flex flex-col"
              >
                <div className="relative aspect-[3/4] w-full overflow-hidden bg-black/40">
                  <img
                    src={manga.coverUrl}
                    alt={manga.title}
                    loading="lazy"
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/20" />

                  {/* Favorito */}
                  <button
                    onClick={(e) => handleToggleFav(manga, e)}
                    className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 backdrop-blur-md border border-white/10 hover:scale-110 transition-transform"
                  >
                    <Heart
                      className={`w-3.5 h-3.5 ${
                        hasFav ? 'fill-[#FF6B1A] text-[#FF6B1A]' : 'text-white/70'
                      }`}
                    />
                  </button>

                  <div className="absolute bottom-2 left-2 right-2 flex items-center justify-between text-[11px] text-white/80">
                    <span className="capitalize">{manga.status}</span>
                    <span>{manga.year || ''}</span>
                  </div>
                </div>

                <div className="p-3 flex flex-col flex-1 justify-between">
                  <h3 className="font-semibold text-xs sm:text-sm text-white line-clamp-2 leading-tight group-hover:text-[#FF6B1A] transition-colors">
                    {manga.title}
                  </h3>
                  <div className="mt-2 flex flex-wrap gap-1">
                    {manga.tags.slice(0, 2).map((t, idx) => (
                      <span
                        key={idx}
                        className="text-[10px] bg-white/5 text-white/50 px-1.5 py-0.5 rounded"
                      >
                        {t}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal de Capítulos */}
      {selectedManga && !activeChapter && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
          <div className="relative w-full max-w-2xl max-h-[85vh] bg-[#121212] border border-white/10 rounded-2xl overflow-hidden shadow-2xl flex flex-col">
            <button
              onClick={() => setSelectedManga(null)}
              className="absolute top-4 right-4 z-20 p-2 rounded-full bg-black/60 text-white/80 hover:text-white"
            >
              <X className="w-5 h-5" />
            </button>

            <div className="p-6 border-b border-white/10 flex gap-4 items-start">
              <img
                src={selectedManga.coverUrl}
                alt={selectedManga.title}
                className="w-20 sm:w-24 aspect-[3/4] rounded-lg object-cover border border-white/10 shadow-lg"
              />
              <div className="flex-1 pr-6">
                <h2 className="text-lg sm:text-xl font-bold text-white mb-1">
                  {selectedManga.title}
                </h2>
                <p className="text-xs text-white/60 line-clamp-2 mb-3">
                  {selectedManga.description}
                </p>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleToggleFav(selectedManga)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium border ${
                      isFavorite(selectedManga.id, 'manga')
                        ? 'bg-rose-500/20 border-rose-500/50 text-rose-400'
                        : 'bg-white/5 border-white/10 text-white hover:bg-white/10'
                    }`}
                  >
                    <Heart
                      className={`w-3.5 h-3.5 ${
                        isFavorite(selectedManga.id, 'manga') ? 'fill-rose-400' : ''
                      }`}
                    />
                    {isFavorite(selectedManga.id, 'manga') ? 'Salvo' : 'Favoritar'}
                  </button>
                </div>
              </div>
            </div>

            {/* Lista de Capítulos */}
            <div className="flex-1 overflow-y-auto p-4 sm:p-6 space-y-2">
              <h4 className="text-xs font-bold tracking-wider uppercase text-white/40 mb-3">
                Capítulos Disponíveis (PT-BR / EN)
              </h4>

              {loadingChapters ? (
                <div className="flex items-center justify-center py-12 gap-2 text-white/50">
                  <Loader2 className="w-5 h-5 animate-spin text-[#FF6B1A]" />
                  <span>Carregando capítulos...</span>
                </div>
              ) : chapters.length === 0 ? (
                <div className="text-center py-12 text-white/40 text-sm">
                  Nenhum capítulo traduzido encontrado neste idioma.
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {chapters.map((ch) => (
                    <button
                      key={ch.id}
                      onClick={() => handleOpenReader(ch)}
                      className="flex items-center justify-between p-3 rounded-lg bg-white/5 hover:bg-[#FF6B1A]/20 border border-white/5 hover:border-[#FF6B1A]/40 transition-colors text-left group"
                    >
                      <div className="flex items-center gap-2 truncate">
                        <BookOpen className="w-4 h-4 text-[#FF6B1A] group-hover:scale-110 transition-transform shrink-0" />
                        <span className="text-xs sm:text-sm font-medium text-white truncate">
                          {ch.title}
                        </span>
                      </div>
                      <span className="text-[10px] uppercase font-bold text-white/40 bg-black/40 px-1.5 py-0.5 rounded ml-2 shrink-0">
                        {ch.language}
                      </span>
                    </button>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Leitor de Mangá Completo */}
      {activeChapter && (
        <div className="fixed inset-0 z-50 bg-[#080808] flex flex-col animate-in fade-in duration-200">
          {/* Header do Leitor */}
          <div className="h-14 px-4 border-b border-white/10 bg-[#0f0f0f]/95 backdrop-blur-md flex items-center justify-between z-10">
            <div className="flex items-center gap-3 truncate">
              <button
                onClick={() => {
                  setActiveChapter(null);
                  setPages([]);
                }}
                className="p-1.5 rounded-lg bg-white/5 text-white/70 hover:text-white hover:bg-white/10"
              >
                <ChevronLeft className="w-5 h-5" />
              </button>
              <div className="truncate">
                <span className="text-xs text-white/40 block">
                  {selectedManga?.title || 'Mangá'}
                </span>
                <span className="text-sm font-semibold text-white truncate block">
                  {activeChapter.title}
                </span>
              </div>
            </div>

            {/* Controles de Página */}
            <div className="flex items-center gap-3">
              {pages.length > 0 && (
                <div className="flex items-center gap-2 bg-white/5 px-3 py-1 rounded-full border border-white/10 text-xs text-white/80">
                  <span>Página</span>
                  <span className="font-bold text-[#FF6B1A]">{currentPageIndex + 1}</span>
                  <span>de</span>
                  <span>{pages.length}</span>
                </div>
              )}

              <button
                onClick={() => {
                  setActiveChapter(null);
                  setSelectedManga(null);
                  setPages([]);
                }}
                className="p-1.5 rounded-lg text-white/60 hover:text-white"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Área da Imagem */}
          <div className="flex-1 relative flex items-center justify-center overflow-auto p-2 sm:p-4 select-none">
            {loadingPages ? (
              <div className="flex flex-col items-center gap-3 text-white/60">
                <Loader2 className="w-8 h-8 animate-spin text-[#FF6B1A]" />
                <p className="text-sm">Carregando páginas do capítulo...</p>
              </div>
            ) : pages.length === 0 ? (
              <div className="text-center text-white/50 text-sm">
                Não foi possível carregar as páginas deste capítulo.
              </div>
            ) : (
              <div className="relative max-w-3xl w-full flex justify-center">
                <img
                  src={pages[currentPageIndex]}
                  alt={`Página ${currentPageIndex + 1}`}
                  className="max-h-[82vh] w-auto object-contain rounded shadow-2xl"
                  onClick={() => {
                    if (currentPageIndex < pages.length - 1) {
                      setCurrentPageIndex((i) => i + 1);
                    }
                  }}
                />

                {/* Botões laterais flutuantes */}
                {currentPageIndex > 0 && (
                  <button
                    onClick={() => setCurrentPageIndex((i) => i - 1)}
                    className="absolute left-2 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 text-white/80 hover:text-white hover:bg-black/90 shadow-xl backdrop-blur-sm"
                  >
                    <ChevronLeft className="w-6 h-6" />
                  </button>
                )}

                {currentPageIndex < pages.length - 1 && (
                  <button
                    onClick={() => setCurrentPageIndex((i) => i + 1)}
                    className="absolute right-2 top-1/2 -translate-y-1/2 p-3 rounded-full bg-black/60 text-white/80 hover:text-white hover:bg-black/90 shadow-xl backdrop-blur-sm"
                  >
                    <ChevronRight className="w-6 h-6" />
                  </button>
                )}
              </div>
            )}
          </div>

          {/* Barra inferior de navegação */}
          {pages.length > 0 && (
            <div className="h-14 px-4 border-t border-white/10 bg-[#0f0f0f] flex items-center justify-center gap-4">
              <button
                disabled={currentPageIndex === 0}
                onClick={() => setCurrentPageIndex((i) => i - 1)}
                className="px-4 py-1.5 rounded-full bg-white/10 text-white text-xs font-medium disabled:opacity-30 hover:bg-white/20 transition-colors"
              >
                Anterior
              </button>

              <input
                type="range"
                min={0}
                max={pages.length - 1}
                value={currentPageIndex}
                onChange={(e) => setCurrentPageIndex(Number(e.target.value))}
                className="w-48 sm:w-80 accent-[#FF6B1A]"
              />

              <button
                disabled={currentPageIndex === pages.length - 1}
                onClick={() => setCurrentPageIndex((i) => i + 1)}
                className="px-4 py-1.5 rounded-full bg-[#FF6B1A] text-white text-xs font-medium disabled:opacity-30 hover:bg-[#ff7b33] transition-colors"
              >
                Próxima
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
