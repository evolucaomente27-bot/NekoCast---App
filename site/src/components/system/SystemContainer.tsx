import { useState } from 'react';
import AnimeExplorer from './AnimeExplorer';
import MangaExplorer from './MangaExplorer';
import FavoritesView from './FavoritesView';
import DownloadsView from './DownloadsView';
import { Tv, BookOpen, Heart, Download, ArrowLeft } from 'lucide-react';

interface SystemContainerProps {
  onBackToLanding: () => void;
  initialTab?: 'animes' | 'mangas' | 'favorites' | 'downloads';
}

export default function SystemContainer({
  onBackToLanding,
  initialTab = 'animes',
}: SystemContainerProps) {
  const [activeTab, setActiveTab] = useState<'animes' | 'mangas' | 'favorites' | 'downloads'>(
    initialTab
  );

  return (
    <div className="min-h-screen bg-[#0A0A0A] text-white pt-20 pb-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        {/* Top bar de navegação do Sistema */}
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 pb-6 mb-8 border-b border-white/10">
          <div className="flex items-center gap-3">
            <button
              onClick={onBackToLanding}
              className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-medium text-white/80 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Apresentação</span>
            </button>

            <div className="h-4 w-px bg-white/20" />

            <div className="flex items-center gap-2">
              <span className="font-bold text-lg text-white">
                Neko<span className="text-[#FF6B1A]">Cast</span>
              </span>
              <span className="text-[10px] bg-[#FF6B1A]/20 text-[#FF6B1A] font-semibold px-2 py-0.5 rounded-full border border-[#FF6B1A]/30">
                Sistema Web
              </span>
            </div>
          </div>

          {/* Abas Principais */}
          <div className="flex items-center gap-1 bg-white/5 p-1 rounded-xl border border-white/10 overflow-x-auto w-full sm:w-auto">
            <button
              onClick={() => setActiveTab('animes')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-all ${
                activeTab === 'animes'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'text-white/70 hover:text-white hover:bg-white/5'
              }`}
            >
              <Tv className="w-4 h-4" />
              Animes
            </button>

            <button
              onClick={() => setActiveTab('mangas')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-all ${
                activeTab === 'mangas'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'text-white/70 hover:text-white hover:bg-white/5'
              }`}
            >
              <BookOpen className="w-4 h-4" />
              Mangás
            </button>

            <button
              onClick={() => setActiveTab('favorites')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-all ${
                activeTab === 'favorites'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'text-white/70 hover:text-white hover:bg-white/5'
              }`}
            >
              <Heart className="w-4 h-4" />
              Minha Lista
            </button>

            <button
              onClick={() => setActiveTab('downloads')}
              className={`flex items-center gap-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-all ${
                activeTab === 'downloads'
                  ? 'bg-[#FF6B1A] text-white shadow-lg shadow-[#FF6B1A]/20'
                  : 'text-white/70 hover:text-white hover:bg-white/5'
              }`}
            >
              <Download className="w-4 h-4" />
              Downloads
            </button>
          </div>
        </div>

        {/* Conteúdo Dinâmico */}
        <div className="animate-in fade-in duration-300">
          {activeTab === 'animes' && <AnimeExplorer />}
          {activeTab === 'mangas' && <MangaExplorer />}
          {activeTab === 'favorites' && <FavoritesView />}
          {activeTab === 'downloads' && <DownloadsView />}
        </div>
      </div>
    </div>
  );
}
