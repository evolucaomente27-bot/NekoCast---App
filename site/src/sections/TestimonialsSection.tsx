import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Star, Quote } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const testimonials = [
  {
    text: 'Finalmente um app de anime que funciona de verdade! A interface é linda e o player nunca trava.',
    name: 'Pedro Silva',
    handle: '@animefan_br',
    avatar: 'PS',
    color: '#FF6B1A',
  },
  {
    text: 'Adoro poder ler mangás via MangaDex e assistir animes no mesmo app. Tudo super fluido e rápido!',
    name: 'Ana Costa',
    handle: '@otaku_sincero',
    avatar: 'AC',
    color: '#FFB800',
  },
  {
    text: 'O download offline salvou minhas viagens de ônibus. Recomendo demais!',
    name: 'Lucas Mendes',
    handle: '@nekocastlover',
    avatar: 'LM',
    color: '#FF8C00',
  },
];

export default function TestimonialsSection() {
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const cardsRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
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

      if (cardsRef.current) {
        const cards = cardsRef.current.children;
        gsap.fromTo(
          cards,
          { opacity: 0, y: 40 },
          {
            opacity: 1,
            y: 0,
            duration: 0.6,
            stagger: 0.15,
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
    <section ref={sectionRef} className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8 bg-white">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-[#0A0A0A] mb-4"
            style={{ opacity: 0 }}
          >
            A Comunidade <span className="gradient-text">NekoCast</span>
          </h2>
          <p className="text-base sm:text-lg text-[#888888] max-w-2xl mx-auto">
            Milhares de usuários já estão aproveitando
          </p>
        </div>

        <div
          ref={cardsRef}
          className="grid md:grid-cols-3 gap-6"
        >
          {testimonials.map((testimonial, index) => (
            <div
              key={index}
              className="relative bg-[#F5F5F5] rounded-2xl p-6 sm:p-8 hover:-translate-y-2 hover:shadow-xl transition-all duration-300"
              style={{ opacity: 0 }}
            >
              {/* Quote icon */}
              <Quote
                className="w-10 h-10 mb-4"
                style={{ color: testimonial.color, opacity: 0.3 }}
              />

              {/* Text */}
              <p className="text-[#0A0A0A] italic leading-relaxed mb-6">
                "{testimonial.text}"
              </p>

              {/* Stars */}
              <div className="flex gap-1 mb-4">
                {[...Array(5)].map((_, i) => (
                  <Star
                    key={i}
                    className="w-4 h-4 fill-[#FFB800] text-[#FFB800]"
                  />
                ))}
              </div>

              {/* Author */}
              <div className="flex items-center gap-3">
                <div
                  className="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-sm"
                  style={{ backgroundColor: testimonial.color }}
                >
                  {testimonial.avatar}
                </div>
                <div>
                  <p className="font-semibold text-[#0A0A0A]">{testimonial.name}</p>
                  <p className="text-sm text-[#888888]">{testimonial.handle}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
