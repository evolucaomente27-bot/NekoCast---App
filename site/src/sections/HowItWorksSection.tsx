import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

const steps = [
  {
    number: '01',
    title: 'Escolha o Conteúdo',
    description: 'Navegue por milhares de animes ou pesquise seus mangás preferidos.',
  },
  {
    number: '02',
    title: 'Anime ou Mangá',
    description: 'Assista seus animes favoritos ou leia capítulos completos via MangaDex.',
  },
  {
    number: '03',
    title: 'Aproveite ou Baixe',
    description: 'Use o player/leitor integrado ou baixe episódios para curtir offline!',
  },
];

export default function HowItWorksSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const lineRef = useRef<HTMLDivElement>(null);
  const stepsRef = useRef<HTMLDivElement>(null);

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

      // Line animation
      if (lineRef.current) {
        gsap.fromTo(
          lineRef.current,
          { scaleX: 0 },
          {
            scaleX: 1,
            duration: 1.5,
            ease: 'power2.out',
            scrollTrigger: {
              trigger: stepsRef.current,
              start: 'top 70%',
            },
          }
        );
      }

      // Steps animation
      if (stepsRef.current) {
        const stepElements = stepsRef.current.children;
        gsap.fromTo(
          stepElements,
          { opacity: 0, y: 50 },
          {
            opacity: 1,
            y: 0,
            duration: 0.8,
            stagger: 0.2,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: stepsRef.current,
              start: 'top 75%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section
      id="como-funciona"
      ref={sectionRef}
      className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8"
      style={{
        background: 'linear-gradient(180deg, #0A0A0A 0%, #111111 50%, #0A0A0A 100%)',
      }}
    >
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-white mb-4"
            style={{ opacity: 0 }}
          >
            Como <span className="gradient-text">Funciona?</span>
          </h2>
          <p className="text-base sm:text-lg text-white/60 max-w-2xl mx-auto">
            Em apenas 3 passos, você já está curtindo seus animes e mangás favoritos
          </p>
        </div>

        <div ref={stepsRef} className="relative grid md:grid-cols-3 gap-8 lg:gap-12">
          {/* Connecting line - desktop only */}
          <div
            ref={lineRef}
            className="hidden md:block absolute top-[80px] left-[16%] right-[16%] h-0.5 origin-left"
            style={{
              background: 'linear-gradient(90deg, #FF6B1A, #FFB800, #FF6B1A)',
              opacity: 0.5,
            }}
          />

          {steps.map((step, index) => (
            <div key={index} className="relative text-center" style={{ opacity: 0 }}>
              {/* Number */}
              <div className="relative inline-flex items-center justify-center mb-6">
                <span
                  className="font-display text-[100px] sm:text-[120px] font-black leading-none select-none"
                  style={{
                    background: 'linear-gradient(135deg, #FF6B1A, #FFB800)',
                    WebkitBackgroundClip: 'text',
                    WebkitTextFillColor: 'transparent',
                    opacity: 0.2,
                  }}
                >
                  {step.number}
                </span>
                {/* Decorative dot */}
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-4 h-4 rounded-full gradient-bg shadow-lg shadow-orange-500/50" />
              </div>

              <h3 className="text-xl sm:text-2xl font-bold text-white mb-3">{step.title}</h3>
              <p className="text-white/60 leading-relaxed max-w-xs mx-auto">{step.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
