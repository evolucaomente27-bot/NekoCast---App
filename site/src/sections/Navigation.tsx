import { useState, useEffect } from 'react';
import { Menu, X, Download, Monitor, Tv } from 'lucide-react';

interface NavigationProps {
  onOpenSystem?: (tab?: 'animes' | 'mangas' | 'favorites' | 'downloads') => void;
  isSystemMode?: boolean;
}

const navLinks = [
  { label: 'Início', href: '#hero' },
  { label: 'Recursos', href: '#recursos' },
  { label: 'Mangá', href: '#manga' },
  { label: 'Como Funciona', href: '#como-funciona' },
  { label: 'Prévia', href: '#previa' },
  { label: 'Downloads', href: '#cta' },
];

export default function Navigation({ onOpenSystem, isSystemMode }: NavigationProps) {
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const androidUrl = 'https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast-1.0.5.apk';
  const windowsUrl = 'https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast_windows-1.0.5.zip';

  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 100);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const scrollTo = (href: string) => {
    setIsMobileMenuOpen(false);
    if (isSystemMode && onOpenSystem) {
      // Se estiver no sistema web e clicar em link da landing page, volta
      window.scrollTo({ top: 0, behavior: 'smooth' });
      return;
    }
    const element = document.querySelector(href);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <>
      <nav
        className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
          isScrolled || isSystemMode
            ? 'bg-[#0A0A0A]/90 backdrop-blur-xl border-b border-white/5'
            : 'bg-transparent'
        }`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16 sm:h-20">
            {/* Logo */}
            <button
              onClick={() => scrollTo('#hero')}
              className="flex items-center gap-2 sm:gap-3 group"
            >
              <img
                src="https://i.imgur.com/cEVu3Fs.png"
                alt="NekoCast"
                className="w-8 h-8 sm:w-10 sm:h-10 object-contain group-hover:scale-110 transition-transform duration-300"
              />
              <span className="font-bold text-lg sm:text-xl text-white tracking-tight">
                Neko<span className="text-[#FF6B1A]">Cast</span>
              </span>
            </button>

            {/* Desktop Nav Links */}
            {!isSystemMode && (
              <div className="hidden md:flex items-center gap-8">
                {navLinks.map((link) => (
                  <button
                    key={link.href}
                    onClick={() => scrollTo(link.href)}
                    className="text-sm text-white/70 hover:text-white transition-colors duration-200 relative group"
                  >
                    {link.label}
                    <span className="absolute -bottom-1 left-0 w-0 h-0.5 bg-gradient-to-r from-[#FF6B1A] to-[#FFB800] group-hover:w-full transition-all duration-300" />
                  </button>
                ))}
              </div>
            )}

            {/* CTA Buttons */}
            <div className="flex items-center gap-2 sm:gap-3">
              {/* Botão para Acessar o Sistema Web */}
              {onOpenSystem && (
                <button
                  onClick={() => onOpenSystem('animes')}
                  className="flex items-center gap-1.5 px-4 py-2 rounded-full bg-[#FF6B1A] text-white text-xs sm:text-sm font-semibold hover:bg-[#ff7b33] hover:scale-105 shadow-md shadow-[#FF6B1A]/20 transition-all duration-300"
                >
                  <Tv className="w-4 h-4" />
                  <span>Sistema Web</span>
                </button>
              )}

              <a
                href={androidUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hidden sm:flex items-center gap-1.5 px-3.5 py-2 bg-white/5 border border-white/10 text-white text-xs sm:text-sm font-medium rounded-full hover:bg-white/10 hover:border-white/20 transition-all duration-300"
              >
                <Download className="w-3.5 h-3.5" />
                <span>APK v1.0.5</span>
              </a>

              <a
                href={windowsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hidden lg:flex items-center gap-1.5 px-3.5 py-2 bg-white/5 border border-white/10 text-white text-xs sm:text-sm font-medium rounded-full hover:bg-white/10 hover:border-white/20 transition-all duration-300"
              >
                <Monitor className="w-3.5 h-3.5" />
                <span>Windows</span>
              </a>

              {/* Mobile Menu Toggle */}
              {!isSystemMode && (
                <button
                  onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
                  className="md:hidden p-2 text-white"
                >
                  {isMobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
                </button>
              )}
            </div>
          </div>
        </div>
      </nav>

      {/* Mobile Menu */}
      {!isSystemMode && (
        <div
          className={`fixed inset-0 z-40 bg-[#0A0A0A]/98 backdrop-blur-xl transition-all duration-500 md:hidden ${
            isMobileMenuOpen ? 'opacity-100 pointer-events-auto' : 'opacity-0 pointer-events-none'
          }`}
        >
          <div className="flex flex-col items-center justify-center h-full gap-6">
            {onOpenSystem && (
              <button
                onClick={() => {
                  setIsMobileMenuOpen(false);
                  onOpenSystem('animes');
                }}
                className="flex items-center gap-2 px-8 py-3.5 bg-[#FF6B1A] text-white text-lg font-bold rounded-full shadow-lg shadow-[#FF6B1A]/30 mb-2"
              >
                <Tv className="w-5 h-5" />
                Acessar Sistema Web
              </button>
            )}

            {navLinks.map((link) => (
              <button
                key={link.href}
                onClick={() => scrollTo(link.href)}
                className="text-xl font-semibold text-white/80 hover:text-[#FF6B1A] transition-colors duration-300"
              >
                {link.label}
              </button>
            ))}

            <div className="flex flex-col gap-3 w-64 mt-4">
              <a
                href={androidUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center gap-2 py-3 bg-white/10 border border-white/20 text-white font-medium rounded-full"
              >
                <Download className="w-4 h-4" />
                Baixar Android APK (v1.0.5)
              </a>
              <a
                href={windowsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center justify-center gap-2 py-3 bg-white/5 border border-white/10 text-white font-medium rounded-full"
              >
                <Monitor className="w-4 h-4" />
                Baixar Windows (v1.0.5)
              </a>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
