import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { BookOpen, ExternalLink, Layers, Globe, Star } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const mangaFeatures = [
  {
    icon: BookOpen,
    title: 'Leitura de Mangá',
    description: 'Leia seus mangás favoritos diretamente no app com leitor otimizado e fluido.',
  },
  {
    icon: Layers,
    title: 'Catálogo MangaDex',
    description: 'Acesse o enorme catálogo do MangaDex com milhares de títulos atualizados.',
  },
  {
    icon: Globe,
    title: 'Múltiplos Idiomas',
    description: 'Mangás disponíveis em português, inglês, espanhol e muitos outros idiomas.',
  },
  {
    icon: Star,
    title: 'Favoritos & Progresso',
    description: 'Salve seus mangás favoritos e continue de onde parou automaticamente.',
  },
];

const popularManga = [
  {
    title: 'One Piece',
    cover: 'https://mangadex.org/covers/a1c7c817-4e59-43b7-9365-09675a149a6f/2c6a3d5f-ae44-4065-afbb-0a5ef09e7763.jpg',
    chapters: '1100+',
    rating: '9.8',
  },
  {
    title: 'Jujutsu Kaisen',
    cover: 'https://mangadex.org/covers/c52b2ce3-7f95-469c-96b0-479524fb7a1a/8dce0e5c-58c4-4521-88e9-1e271b90a5cb.jpg',
    chapters: '260+',
    rating: '9.5',
  },
  {
    title: 'Chainsaw Man',
    cover: 'https://mangadex.org/covers/a77742b1-befd-49a4-bff5-1571f00f8e3c/76d09f53-a8e8-4bc2-bd63-9e2aa tried-4070-9b21-6b1a59bfc80f.jpg',
    chapters: '170+',
    rating: '9.3',
  },
  {
    title: 'Solo Leveling',
    cover: 'https://mangadex.org/covers/32d76d19-8a05-4db0-9fc2-e0b0648fe9d0/e90bdc47-c8b4-4a5c-b4a9-941b78e79b87.jpg',
    chapters: '200+',
    rating: '9.6',
  },
];

interface MangaSectionProps {
  onOpenSystem?: (tab?: 'animes' | 'mangas' | 'favorites' | 'downloads') => void;
}

export default function MangaSection({ onOpenSystem }: MangaSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const featuresRef = useRef<HTMLDivElement>(null);
  const mangaGridRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Title animation
      if (titleRef.current) {
        gsap.fromTo(
          titleRef.current,
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.8,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: titleRef.current,
              start: 'top 85%',
            },
          }
        );
      }

      // Features animation
      if (featuresRef.current) {
        const cards = featuresRef.current.children;
        gsap.fromTo(
          cards,
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.6,
            stagger: 0.1,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: featuresRef.current,
              start: 'top 80%',
            },
          }
        );
      }

      // Manga grid animation
      if (mangaGridRef.current) {
        const items = mangaGridRef.current.children;
        gsap.fromTo(
          items,
          { opacity: 0, scale: 0.9, y: 30 },
          {
            opacity: 1,
            scale: 1,
            y: 0,
            duration: 0.6,
            stagger: 0.12,
            ease: 'back.out(1.2)',
            scrollTrigger: {
              trigger: mangaGridRef.current,
              start: 'top 80%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      id="manga"
      ref={sectionRef}
      className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8 overflow-hidden"
      style={{
        background: 'linear-gradient(180deg, #0A0A0A 0%, #0D0D15 30%, #0D0D15 70%, #0A0A0A 100%)',
      }}
    >
      {/* Decorative manga-style lines */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-20 left-0 w-full h-px bg-gradient-to-r from-transparent via-purple-500/20 to-transparent" />
        <div className="absolute bottom-20 left-0 w-full h-px bg-gradient-to-r from-transparent via-[#FF6B1A]/20 to-transparent" />
        {/* Floating orbs */}
        <div className="absolute top-1/4 left-10 w-48 h-48 rounded-full bg-purple-600/5 blur-3xl" />
        <div className="absolute bottom-1/4 right-10 w-64 h-64 rounded-full bg-[#FF6B1A]/5 blur-3xl" />
      </div>

      <div className="max-w-6xl mx-auto relative z-10">
        {/* Header */}
        <div className="text-center mb-16">
          <div className="flex items-center justify-center gap-2 mb-4">
            <BookOpen className="w-5 h-5 text-purple-400" />
            <span className="text-sm font-medium text-purple-400 tracking-wider uppercase">
              Powered by MangaDex
            </span>
          </div>
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-white mb-4"
            style={{ opacity: 0 }}
          >
            Mangá via{' '}
            <span
              style={{
                background: 'linear-gradient(135deg, #FF6B1A, #E44C65, #A855F7)',
                WebkitBackgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
              }}
            >
              MangaDex
            </span>
          </h2>
          <p className="text-base sm:text-lg text-white/60 max-w-2xl mx-auto">
            Além de animes, agora você pode ler mangás com o catálogo completo do MangaDex integrado ao NekoCast.
          </p>
        </div>

        {/* Features Grid */}
        <div
          ref={featuresRef}
          className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-16"
        >
          {mangaFeatures.map((feature, index) => (
            <div
              key={index}
              className="group bg-white/5 backdrop-blur-sm rounded-2xl p-6 border border-white/5 hover:border-purple-500/30 hover:-translate-y-1 transition-all duration-300"
              style={{ opacity: 0 }}
            >
              <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-[#FF6B1A] to-purple-600 flex items-center justify-center mb-4 group-hover:rotate-[8deg] transition-transform duration-300">
                <feature.icon className="w-6 h-6 text-white" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">{feature.title}</h3>
              <p className="text-sm text-white/50 leading-relaxed">{feature.description}</p>
            </div>
          ))}
        </div>

        {/* Popular Manga Showcase */}
        <div className="text-center mb-8">
          <h3 className="text-xl sm:text-2xl font-bold text-white mb-2">
            Mangás <span className="gradient-text">Populares</span>
          </h3>
          <p className="text-sm text-white/50">
            Alguns dos títulos mais lidos disponíveis no NekoCast
          </p>
        </div>

        <div
          ref={mangaGridRef}
          className="grid grid-cols-2 sm:grid-cols-4 gap-4 sm:gap-6 mb-12"
        >
          {popularManga.map((manga, index) => (
            <div
              key={index}
              onClick={() => onOpenSystem?.('mangas')}
              className="group relative rounded-2xl overflow-hidden cursor-pointer"
              style={{ opacity: 0 }}
            >
              {/* Cover placeholder with gradient */}
              <div className="relative aspect-[3/4] rounded-2xl overflow-hidden bg-gradient-to-br from-[#1a1a2e] to-[#16213e] border border-white/5 group-hover:border-purple-500/40 transition-all duration-300">
                {/* Manga cover pattern */}
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="text-center px-3">
                    <BookOpen className="w-10 h-10 sm:w-12 sm:h-12 text-white/20 mx-auto mb-3" />
                    <p className="text-white font-bold text-sm sm:text-base leading-tight">{manga.title}</p>
                    <div className="flex items-center justify-center gap-1 mt-2">
                      <Star className="w-3 h-3 text-[#FFB800] fill-[#FFB800]" />
                      <span className="text-xs text-[#FFB800]">{manga.rating}</span>
                    </div>
                    <p className="text-xs text-white/40 mt-1">{manga.chapters} caps</p>
                  </div>
                </div>

                {/* Hover overlay */}
                <div className="absolute inset-0 bg-gradient-to-t from-purple-900/80 via-transparent to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end justify-center pb-4">
                  <span className="text-white text-sm font-semibold flex items-center gap-1">
                    Ler agora <ExternalLink className="w-3 h-3" />
                  </span>
                </div>
              </div>
            </div>
          ))}
        </div>

        {/* Botão para Abrir Catálogo Completo */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          {onOpenSystem && (
            <button
              onClick={() => onOpenSystem('mangas')}
              className="inline-flex items-center gap-2 px-8 py-3.5 bg-gradient-to-r from-purple-600 to-[#FF6B1A] text-white font-bold rounded-full text-sm sm:text-base hover:scale-105 transition-all shadow-lg shadow-purple-500/20 cursor-pointer"
            >
              <BookOpen className="w-4 h-4" />
              Explorar Catálogo Completo & Ler Online
            </button>
          )}

          <a
            href="https://mangadex.org"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-2 px-6 py-3 bg-white/5 border border-white/10 rounded-full text-sm text-white/60 hover:text-white hover:border-purple-500/40 hover:bg-white/10 transition-all duration-300"
          >
            <span>Catálogo MangaDex API (Serverless)</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
        </div>
      </div>
    </section>
  );
}
