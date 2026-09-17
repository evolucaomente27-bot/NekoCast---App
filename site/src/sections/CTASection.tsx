import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Download, Monitor } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

export default function CTASection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (contentRef.current) {
        const children = contentRef.current.children;
        gsap.fromTo(
          children,
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.8,
            stagger: 0.1,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: sectionRef.current,
              start: 'top 70%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative py-24 sm:py-32 lg:py-40 px-4 sm:px-6 lg:px-8 overflow-hidden"
      style={{
        background: 'linear-gradient(135deg, #FF6B1A 0%, #FF8C00 40%, #FFB800 100%)',
      }}
    >
      {/* Decorative floating shapes */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {/* Tail shapes */}
        {[...Array(8)].map((_, i) => (
          <svg
            key={i}
            className="absolute opacity-10"
            style={{
              left: `${10 + i * 12}%`,
              top: `${10 + (i % 3) * 30}%`,
              width: `${30 + (i % 3) * 20}px`,
              height: `${30 + (i % 3) * 20}px`,
              transform: `rotate(${i * 45}deg)`,
              animation: `float-particle ${10 + i * 2}s linear infinite`,
              animationDelay: `${i * 0.8}s`,
            }}
            viewBox="0 0 24 24"
            fill="white"
          >
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10c1.19 0 2.34-.21 3.41-.6.3-.11.49-.4.49-.72 0-.43-.35-.78-.78-.78-.17 0-.33.06-.46.14-.79.29-1.64.46-2.52.46-3.86 0-7-3.14-7-7s3.14-7 7-7 7 3.14 7 7c0 .88-.17 1.73-.46 2.52-.08.13-.14.29-.14.46 0 .43.35.78.78.78.32 0 .61-.19.72-.49.39-1.07.6-2.22.6-3.41 0-5.52-4.48-10-10-10z" />
          </svg>
        ))}

        {/* Large gradient orbs */}
        <div className="absolute -top-40 -left-40 w-80 h-80 rounded-full bg-white/10 blur-3xl" />
        <div className="absolute -bottom-40 -right-40 w-80 h-80 rounded-full bg-white/10 blur-3xl" />
      </div>

      <div ref={contentRef} className="relative z-10 max-w-4xl mx-auto text-center">
        <h2
          className="text-3xl sm:text-4xl lg:text-5xl xl:text-6xl font-black text-white mb-6 leading-tight"
          style={{ opacity: 0 }}
        >
          Pronto para entrar no universo NekoCast?
        </h2>

        <p
          className="text-lg sm:text-xl text-white/90 mb-10 max-w-2xl mx-auto"
          style={{ opacity: 0 }}
        >
          Baixe agora e comece a assistir seus animes favoritos com estilo.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4" style={{ opacity: 0 }}>
          <a
            href="https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast-1.0.5.apk"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-3 px-10 py-5 bg-white text-[#FF6B1A] font-bold text-lg sm:text-xl rounded-full hover:scale-105 hover:shadow-2xl hover:shadow-black/20 transition-all duration-300"
            style={{ animation: 'pulse-glow 2s ease-in-out infinite' }}
          >
            <Download className="w-6 h-6" />
            Android APK (v1.0.5)
          </a>
          <a
            href="https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast_windows-1.0.5.zip"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-3 px-10 py-5 bg-white/20 border-2 border-white/40 text-white font-bold text-lg sm:text-xl rounded-full hover:scale-105 hover:bg-white/30 hover:shadow-2xl hover:shadow-black/20 transition-all duration-300"
          >
            <Monitor className="w-6 h-6" />
            Windows (v1.0.5)
          </a>
        </div>

        <p className="text-sm text-white/60 mt-6" style={{ opacity: 0 }}>
          Android 6.0+ • Windows 10+ • Gratuito • Sem anúncios
        </p>
      </div>
    </section>
  );
}
