import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Play, Monitor, Download, BookOpen, Heart, Layout } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const features = [
  {
    icon: Play,
    title: 'Player Integrado',
    description: 'Reproduza seus animes favoritos diretamente no app com nosso player otimizado e fluido.',
  },
  {
    icon: Monitor,
    title: 'Player Alternativo',
    description: 'Prefere outro player? Sem problemas! Use o player externo do seu dispositivo.',
  },
  {
    icon: Download,
    title: 'Downloads',
    description: 'Baixe episódios para assistir offline quando e onde quiser.',
  },
  {
    icon: BookOpen,
    title: 'Mangás via MangaDex',
    description: 'Leia milhares de títulos e capítulos diretamente no app com catálogo completo do MangaDex.',
  },
  {
    icon: Heart,
    title: 'Lista de Favoritos',
    description: 'Organize seus animes e mangás favoritos em uma lista personalizada.',
  },
  {
    icon: Layout,
    title: 'Interface Moderna',
    description: 'Design limpo, intuitivo e bonito que torna a navegação uma experiência prazerosa.',
  },
];

export default function FeaturesSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

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

      // Cards animation
      if (cardsRef.current) {
        const cards = cardsRef.current.children;
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
              trigger: cardsRef.current,
              start: 'top 80%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section id="recursos" ref={sectionRef} className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-white mb-4"
            style={{ opacity: 0 }}
          >
            Recursos que Você Vai <span className="gradient-text">Amar</span>
          </h2>
          <p className="text-base sm:text-lg text-white/60 max-w-2xl mx-auto">
            Tudo que você precisa para uma experiência de animes e mangás completa, em um só app.
          </p>
        </div>

        <div
          ref={cardsRef}
          className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {features.map((feature, index) => (
            <div
              key={index}
              className="group bg-white rounded-2xl p-6 sm:p-8 card-shadow hover:-translate-y-2 hover:card-shadow-hover transition-all duration-300"
              style={{ opacity: 0 }}
            >
              <div className="w-14 h-14 rounded-xl gradient-bg flex items-center justify-center mb-5 group-hover:rotate-[10deg] transition-transform duration-300">
                <feature.icon className="w-7 h-7 text-white" />
              </div>
              <h3 className="text-xl font-bold text-[#0A0A0A] mb-3">{feature.title}</h3>
              <p className="text-[#888888] leading-relaxed">{feature.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
