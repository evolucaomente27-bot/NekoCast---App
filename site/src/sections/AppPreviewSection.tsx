import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

const previews = [
  { image: '/assets/preview-home.jpg', label: 'Tela Inicial' },
  { image: '/assets/preview-search.jpg', label: 'Busca' },
  { image: '/assets/preview-detail.jpg', label: 'Detalhes' },
  { image: '/assets/preview-player.jpg', label: 'Player' },
  { image: '/assets/preview-downloads.jpg', label: 'Downloads' },
  { image: '/assets/preview-favorites.jpg', label: 'Favoritos' },
  { image: '/assets/preview-settings.jpg', label: 'Configurações' },
  { image: '/assets/preview-sources.jpg', label: 'Mangás' },
];

export default function AppPreviewSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const gridRef = useRef<HTMLDivElement>(null);

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

      // Cards 3D animation
      if (gridRef.current) {
        const cards = Array.from(gridRef.current.children);

        cards.forEach((card, index) => {
          const el = card as HTMLElement;
          const col = index % 4;
          const isLeft = col < 2;

          gsap.fromTo(
            el,
            {
              opacity: 0.3,
              rotateY: isLeft ? -15 : 15,
              z: -200,
              y: 60,
            },
            {
              opacity: 1,
              rotateY: 0,
              z: 0,
              y: 0,
              duration: 1,
              ease: 'power2.out',
              scrollTrigger: {
                trigger: el,
                start: 'top 90%',
                end: 'center 50%',
                scrub: 1,
              },
            }
          );
        });
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      id="previa"
      ref={sectionRef}
      className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8 overflow-hidden"
      style={{ backgroundColor: '#0A0A0A' }}
    >
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-white mb-4"
            style={{ opacity: 0 }}
          >
            Veja o NekoCast em <span className="gradient-text">Ação</span>
          </h2>
          <p className="text-base sm:text-lg text-white/60 max-w-2xl mx-auto">
            Uma interface pensada para você
          </p>
        </div>

        <div
          ref={gridRef}
          className="grid grid-cols-2 md:grid-cols-4 gap-4 sm:gap-6"
          style={{ perspective: '1000px' }}
        >
          {previews.map((preview, index) => (
            <div
              key={index}
              className="group relative rounded-2xl overflow-hidden"
              style={{
                transformStyle: 'preserve-3d',
                boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
                opacity: 0,
              }}
            >
              {/* Phone frame */}
              <div className="relative bg-[#1a1a1a] rounded-2xl p-2 sm:p-3 border border-white/5 hover:border-[#FF6B1A]/30 transition-colors duration-300">
                {/* Notch */}
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-16 sm:w-20 h-4 sm:h-5 bg-[#0A0A0A] rounded-b-xl z-10" />

                <div className="relative aspect-[9/16] rounded-xl overflow-hidden bg-[#0A0A0A]">
                  <img
                    src={preview.image}
                    alt={preview.label}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                  />
                </div>

                {/* Label */}
                <p className="text-center text-xs sm:text-sm text-white/70 mt-2 sm:mt-3 font-medium">
                  {preview.label}
                </p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
