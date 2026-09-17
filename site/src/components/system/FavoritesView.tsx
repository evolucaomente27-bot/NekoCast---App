import { useState, useEffect } from 'react';
import type { FavoriteItem } from '../../services/favoritesService';
import {
  getFavorites,
  toggleFavorite,
} from '../../services/favoritesService';
import { Heart, Trash2, BookOpen, Tv } from 'lucide-react';

export default function FavoritesView() {
  const [items, setItems] = useState<FavoriteItem[]>([]);
  const [filter, setFilter] = useState<'all' | 'anime' | 'manga'>('all');

  const loadItems = () => {
    setItems(getFavorites());
  };

  useEffect(() => {
    loadItems();

    const handleUpdate = () => loadItems();
    window.addEventListener('nekocast_favorites_updated', handleUpdate);
    return () => window.removeEventListener('nekocast_favorites_updated', handleUpdate);
  }, []);

  const handleRemove = (item: FavoriteItem) => {
    toggleFavorite({
      id: item.id,
      title: item.title,
      imageUrl: item.imageUrl,
      type: item.type,
    });
    loadItems();
  };

  const filteredItems = items.filter((item) => {
    if (filter === 'all') return true;
    return item.type === filter;
  });

  return (
    <div className="w-full">
      {/* Header com Filtros */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 mb-8">
        <div>
          <h2 className="text-xl sm:text-2xl font-bold text-white flex items-center gap-2">
            <Heart className="w-6 h-6 fill-[#FF6B1A] text-[#FF6B1A]" />
            Minha Lista ({items.length})
          </h2>
          <p className="text-xs sm:text-sm text-white/50">
            Salvo localmente no seu navegador (sem necessidade de conta ou servidor)
          </p>
        </div>

        <div className="flex items-center gap-2 bg-white/5 p-1 rounded-full border border-white/10">
          <button
            onClick={() => setFilter('all')}
            className={`px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
              filter === 'all'
                ? 'bg-[#FF6B1A] text-white shadow-md'
                : 'text-white/60 hover:text-white'
            }`}
          >
            Todos ({items.length})
          </button>
          <button
            onClick={() => setFilter('anime')}
            className={`px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
              filter === 'anime'
                ? 'bg-[#FF6B1A] text-white shadow-md'
                : 'text-white/60 hover:text-white'
            }`}
          >
            Animes ({items.filter((i) => i.type === 'anime').length})
          </button>
          <button
            onClick={() => setFilter('manga')}
            className={`px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
              filter === 'manga'
                ? 'bg-[#FF6B1A] text-white shadow-md'
                : 'text-white/60 hover:text-white'
            }`}
          >
            Mangás ({items.filter((i) => i.type === 'manga').length})
          </button>
        </div>
      </div>

      {/* Lista / Grid */}
      {filteredItems.length === 0 ? (
        <div className="text-center py-24 bg-white/5 rounded-2xl border border-white/5">
          <Heart className="w-12 h-12 text-white/20 mx-auto mb-3" />
          <p className="text-white font-medium">Sua lista está vazia.</p>
          <p className="text-white/40 text-sm mt-1 max-w-sm mx-auto">
            Explore os animes e mangás e clique no ícone de coração para salvar aqui.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-4">
          {filteredItems.map((item) => (
            <div
              key={`${item.type}-${item.id}`}
              className="group relative bg-[#141414] rounded-xl overflow-hidden border border-white/5 hover:border-[#FF6B1A]/40 transition-all flex flex-col"
            >
              <div className="relative aspect-[3/4] w-full overflow-hidden bg-black/40">
                <img
                  src={item.imageUrl}
                  alt={item.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-black/20" />

                {/* Badge Tipo */}
                <div className="absolute top-2 left-2 flex items-center gap-1 bg-black/70 backdrop-blur-md px-2 py-0.5 rounded-md border border-white/10 text-[10px] font-semibold text-white/80 uppercase">
                  {item.type === 'anime' ? (
                    <>
                      <Tv className="w-3 h-3 text-[#FF6B1A]" />
                      Anime
                    </>
                  ) : (
                    <>
                      <BookOpen className="w-3 h-3 text-[#FFB800]" />
                      Mangá
                    </>
                  )}
                </div>

                {/* Remover */}
                <button
                  onClick={() => handleRemove(item)}
                  title="Remover dos favoritos"
                  className="absolute top-2 right-2 p-1.5 rounded-full bg-black/60 backdrop-blur-md text-white/70 hover:text-rose-400 hover:bg-black/90 transition-colors"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>

                {item.scoreOrTag && (
                  <div className="absolute bottom-2 left-2 text-xs font-semibold text-white/90">
                    {item.scoreOrTag}
                  </div>
                )}
              </div>

              <div className="p-3">
                <h3 className="font-semibold text-xs sm:text-sm text-white line-clamp-2 leading-tight">
                  {item.title}
                </h3>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
