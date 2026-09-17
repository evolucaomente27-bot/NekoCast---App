import { useEffect, useRef, useState } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Play, BookOpen, Download, Search } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const stats = [
  { icon: Search, value: 10000, suffix: '+', label: 'Animes disponíveis' },
  { icon: BookOpen, value: 50000, suffix: '+', label: 'Mangás MangaDex', sublabel: 'Catálogo integrado' },
  { icon: Play, value: 2, suffix: '', label: 'Player Dual', sublabel: 'Interno e Externo' },
  { icon: Download, value: 1, suffix: '', label: 'Offline', sublabel: 'Download de episódios' },
];

function AnimatedCounter({ value, suffix, inView }: { value: number; suffix: string; inView: boolean }) {
  const [count, setCount] = useState(0);
  const countRef = useRef({ val: 0 });

  useEffect(() => {
    if (!inView) return;

    const obj = countRef.current;
    gsap.to(obj, {
      val: value,
      duration: 2,
      ease: 'power2.out',
      onUpdate: () => {
        setCount(Math.round(obj.val));
      },
    });
  }, [inView, value]);

  return (
    <span>
      {value >= 1000 && count >= 1000 ? `${Math.round(count / 1000)}k` : count}
      {suffix}
    </span>
  );
}

export default function StatsSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const [inView, setInView] = useState(false);
  const cardsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      ScrollTrigger.create({
        trigger: sectionRef.current,
        start: 'top 80%',
        onEnter: () => setInView(true),
      });

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
              trigger: sectionRef.current,
              start: 'top 80%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="relative z-10 -mt-20 px-4 sm:px-6 lg:px-8">
      {/* Floating particles */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {[...Array(6)].map((_, i) => (
          <div
            key={i}
            className="absolute w-1 h-1 rounded-full bg-[#FFB800]"
            style={{
              left: `${15 + i * 15}%`,
              bottom: '20%',
              opacity: 0.3,
              animation: `float-particle ${8 + i * 2}s linear infinite`,
              animationDelay: `${i * 1.5}s`,
            }}
          />
        ))}
      </div>

      <div
        ref={cardsRef}
        className="max-w-6xl mx-auto grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 bg-[#0A0A0A]/80 backdrop-blur-xl rounded-3xl p-6 sm:p-8 border border-white/5"
        style={{
          boxShadow: '0 -20px 60px rgba(255, 107, 26, 0.15), 0 4px 24px rgba(0,0,0,0.3)',
        }}
      >
        {stats.map((stat, index) => (
          <div
            key={index}
            className="flex flex-col items-center text-center p-4 rounded-2xl hover:bg-white/5 transition-colors duration-300 group"
          >
            <div className="w-12 h-12 sm:w-14 sm:h-14 rounded-xl gradient-bg flex items-center justify-center mb-3 group-hover:scale-110 transition-transform duration-300">
              <stat.icon className="w-6 h-6 sm:w-7 sm:h-7 text-white" />
            </div>
            <div className="text-2xl sm:text-3xl lg:text-4xl font-black gradient-text mb-1">
              <AnimatedCounter value={stat.value} suffix={stat.suffix} inView={inView} />
            </div>
            <p className="text-xs sm:text-sm text-white/70 font-medium">{stat.label}</p>
            {stat.sublabel && (
              <p className="text-xs text-white/50">{stat.sublabel}</p>
            )}
          </div>
        ))}
      </div>
    </section>
  );
}
