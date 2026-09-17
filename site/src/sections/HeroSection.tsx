import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Download, ChevronDown, Sparkles, Monitor, Play } from 'lucide-react';
import HeroBackground from './HeroBackground';

gsap.registerPlugin(ScrollTrigger);

interface HeroSectionProps {
  onOpenSystem?: (tab?: 'animes' | 'mangas' | 'favorites' | 'downloads') => void;
}

export default function HeroSection({ onOpenSystem }: HeroSectionProps) {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const subtitleRef = useRef<HTMLParagraphElement>(null);
  const descRef = useRef<HTMLParagraphElement>(null);
  const buttonsRef = useRef<HTMLDivElement>(null);
  const logoRef = useRef<HTMLDivElement>(null);
  const scrollIndicatorRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      // Title character animation
      if (titleRef.current) {
        const text = titleRef.current.textContent || '';
        titleRef.current.innerHTML = '';
        const chars = text.split('').map((char) => {
          const span = document.createElement('span');
          span.textContent = char;
          span.style.display = 'inline-block';
          span.style.opacity = '0';
          span.style.transform = 'translateY(80%)';
          titleRef.current!.appendChild(span);
          return span;
        });

        gsap.to(chars, {
          opacity: 1,
          y: 0,
          duration: 0.8,
          stagger: 0.04,
          ease: 'power3.out',
          delay: 0.3,
        });
      }

      // Subtitle
      gsap.fromTo(
        subtitleRef.current,
        { opacity: 0, y: 30 },
        { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out', delay: 0.6 }
      );

      // Description
      gsap.fromTo(
        descRef.current,
        { opacity: 0, y: 30 },
        { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out', delay: 0.8 }
      );

      // Buttons
      gsap.fromTo(
        buttonsRef.current,
        { opacity: 0, y: 30 },
        { opacity: 1, y: 0, duration: 0.8, ease: 'power3.out', delay: 1.0 }
      );

      // Logo 3D
      gsap.fromTo(
        logoRef.current,
        { opacity: 0, scale: 0.8 },
        { opacity: 1, scale: 1, duration: 1.0, ease: 'back.out(1.2)', delay: 0.5 }
      );

      // Scroll indicator
      gsap.fromTo(
        scrollIndicatorRef.current,
        { opacity: 0 },
        { opacity: 1, duration: 0.5, delay: 1.5 }
      );
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  // Mouse tilt effect for logo
  useEffect(() => {
    const logo = logoRef.current;
    if (!logo) return;

    let targetX = 0;
    let targetY = 0;
    let currentX = 0;
    let currentY = 0;
    let rafId: number;

    const handleMouseMove = (e: MouseEvent) => {
      const centerX = window.innerWidth / 2;
      const centerY = window.innerHeight / 2;
      targetX = ((e.clientX - centerX) / centerX) * 15;
      targetY = ((e.clientY - centerY) / centerY) * -15;
    };

    const animate = () => {
      currentX += (targetX - currentX) * 0.08;
      currentY += (targetY - currentY) * 0.08;
      logo.style.transform = `perspective(1000px) rotateY(${currentX}deg) rotateX(${currentY}deg)`;
      rafId = requestAnimationFrame(animate);
    };

    window.addEventListener('mousemove', handleMouseMove, { passive: true });
    rafId = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      cancelAnimationFrame(rafId);
    };
  }, []);

  return (
    <section
      id="hero"
      ref={sectionRef}
      className="relative min-h-[100dvh] flex items-center overflow-hidden"
    >
      <HeroBackground />

      <div className="relative z-10 w-full max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20 pt-24">
        <div className="grid lg:grid-cols-2 gap-8 lg:gap-12 items-center">
          {/* Left: Text */}
          <div className="text-center lg:text-left">
            <div className="flex items-center justify-center lg:justify-start gap-2 mb-4">
              <Sparkles className="w-5 h-5 text-[#FFB800]" />
              <span className="text-sm font-medium text-[#FFB800] tracking-wider uppercase">
                App de Anime Premium
              </span>
            </div>

            <h1
              ref={titleRef}
              className="text-5xl sm:text-6xl lg:text-7xl xl:text-8xl font-black text-white leading-none tracking-tight mb-4"
            >
              NekoCast
            </h1>

            <p
              ref={subtitleRef}
              className="text-lg sm:text-xl lg:text-2xl text-[#FF6B1A] font-semibold mb-4"
              style={{ opacity: 0 }}
            >
              Seu portal para animes e mangás com estilo
            </p>

            <p
              ref={descRef}
              className="text-base sm:text-lg text-white/70 max-w-xl mx-auto lg:mx-0 mb-8 leading-relaxed"
              style={{ opacity: 0 }}
            >
              Assista animes, leia mangás via MangaDex, use player alternativo, baixe episódios e organize sua lista em um app rápido e bonito.
            </p>

            <div
              ref={buttonsRef}
              className="flex flex-col sm:flex-row flex-wrap items-center justify-center lg:justify-start gap-3 sm:gap-4"
              style={{ opacity: 0 }}
            >
              {onOpenSystem && (
                <button
                  onClick={() => onOpenSystem('animes')}
                  className="flex items-center gap-2.5 px-8 py-4 bg-gradient-to-r from-[#FF6B1A] to-[#FF8C38] text-white font-bold rounded-full text-base sm:text-lg hover:scale-105 hover:shadow-xl hover:shadow-orange-500/30 transition-all duration-300 w-full sm:w-auto justify-center cursor-pointer"
                  style={{ animation: 'pulse-glow 2s ease-in-out infinite' }}
                >
                  <Play className="w-5 h-5 fill-white" />
                  Assistir / Usar Online
                </button>
              )}
              <a
                href="https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast-1.0.5.apk"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 px-6 py-4 bg-white/10 border-2 border-white/20 text-white font-semibold rounded-full text-sm sm:text-base hover:scale-105 hover:bg-white/20 hover:border-white/40 transition-all duration-300 w-full sm:w-auto justify-center"
              >
                <Download className="w-4 h-4" />
                Android (v1.0.5)
              </a>
              <a
                href="https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast_windows-1.0.5.zip"
                target="_blank"
                rel="noopener noreferrer"
                className="flex items-center gap-2 px-6 py-4 bg-white/10 border-2 border-white/20 text-white font-semibold rounded-full text-sm sm:text-base hover:scale-105 hover:bg-white/20 hover:border-white/40 transition-all duration-300 w-full sm:w-auto justify-center"
              >
                <Monitor className="w-4 h-4" />
                Windows (v1.0.5)
              </a>
            </div>
          </div>

          {/* Right: Logo 3D */}
          <div className="flex items-center justify-center lg:justify-end">
            <div
              ref={logoRef}
              className="relative w-64 h-64 sm:w-80 sm:h-80 lg:w-96 lg:h-96"
              style={{ opacity: 0, transformStyle: 'preserve-3d' }}
            >
              {/* Glow behind logo */}
              <div className="absolute inset-0 rounded-full bg-gradient-to-br from-[#FF6B1A]/20 to-[#FFB800]/20 blur-3xl scale-150" />

              {/* Logo image */}
              <img
                src="https://i.imgur.com/cEVu3Fs.png"
                alt="NekoCast Logo"
                className="relative w-full h-full object-contain drop-shadow-2xl"
                style={{
                  filter: 'drop-shadow(0 0 40px rgba(255, 107, 26, 0.4))',
                }}
              />

              {/* Floating elements */}
              <div className="absolute -top-4 -right-4 w-12 h-12 rounded-full bg-gradient-to-br from-[#FF6B1A] to-[#FFB800] opacity-60 blur-sm" />
              <div className="absolute -bottom-6 -left-6 w-8 h-8 rounded-full bg-[#FFB800] opacity-40 blur-sm" />
            </div>
          </div>
        </div>
      </div>

      {/* Scroll indicator */}
      <div
        ref={scrollIndicatorRef}
        className="absolute bottom-8 left-1/2 -translate-x-1/2 z-10 flex flex-col items-center gap-2"
        style={{ opacity: 0 }}
      >
        <span className="text-xs text-white/50 tracking-wider">ROLE PARA EXPLORAR</span>
        <ChevronDown
          className="w-5 h-5 text-white/50"
          style={{ animation: 'scroll-indicator 2s ease-in-out infinite' }}
        />
      </div>
    </section>
  );
}
