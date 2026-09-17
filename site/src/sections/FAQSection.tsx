import { useState, useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { Plus } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const faqs = [
  {
    question: 'O NekoCast é gratuito?',
    answer: 'Sim! O NekoCast é 100% gratuito para baixar e usar.',
  },
  {
    question: 'É seguro baixar o APK?',
    answer: 'Sim, nosso APK é verificado e seguro. Recomendamos sempre baixar do link oficial.',
  },
  {
    question: 'Preciso de conta para usar?',
    answer: 'Não! Basta baixar e começar a assistir. Sem cadastros complicados.',
  },
  {
    question: 'Posso assistir offline?',
    answer: 'Sim! Baixe os episódios e assista sem internet.',
  },
  {
    question: 'Posso ler mangás no app?',
    answer: 'Sim! O NekoCast conta com catálogo completo e atualizado do MangaDex para leitura de mangás diretamente no app.',
  },
  {
    question: 'O app funciona em todos os dispositivos Android?',
    answer: 'O NekoCast funciona em dispositivos Android 6.0 ou superior.',
  },
];

function FAQItem({ question, answer, isOpen, onClick }: {
  question: string;
  answer: string;
  isOpen: boolean;
  onClick: () => void;
}) {
  const contentRef = useRef<HTMLDivElement>(null);

  return (
    <div className="border-b border-[#0A0A0A]/10 last:border-b-0">
      <button
        onClick={onClick}
        className="w-full flex items-center justify-between py-5 sm:py-6 text-left group"
      >
        <span className="text-base sm:text-lg font-semibold text-[#0A0A0A] pr-4 group-hover:text-[#FF6B1A] transition-colors duration-200">
          {question}
        </span>
        <div
          className="flex-shrink-0 w-8 h-8 rounded-full bg-[#F5F5F5] flex items-center justify-center transition-all duration-300"
          style={{
            transform: isOpen ? 'rotate(45deg)' : 'rotate(0deg)',
            backgroundColor: isOpen ? '#FF6B1A' : '#F5F5F5',
          }}
        >
          <Plus
            className="w-4 h-4 transition-colors duration-200"
            style={{ color: isOpen ? '#FFFFFF' : '#0A0A0A' }}
          />
        </div>
      </button>
      <div
        ref={contentRef}
        className="overflow-hidden transition-all duration-300 ease-in-out"
        style={{
          maxHeight: isOpen ? '200px' : '0px',
          opacity: isOpen ? 1 : 0,
        }}
      >
        <p className="pb-5 sm:pb-6 text-[#888888] leading-relaxed pr-12">
          {answer}
        </p>
      </div>
    </div>
  );
}

export default function FAQSection() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);
  const sectionRef = useRef<HTMLDivElement>(null);
  const titleRef = useRef<HTMLHeadingElement>(null);
  const faqRef = useRef<HTMLDivElement>(null);

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

      if (faqRef.current) {
        gsap.fromTo(
          faqRef.current,
          { opacity: 0, y: 30 },
          {
            opacity: 1,
            y: 0,
            duration: 0.6,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: faqRef.current,
              start: 'top 80%',
            },
          }
        );
      }
    }, sectionRef);

    return () => ctx.revert();
  }, []);

  return (
    <section ref={sectionRef} className="relative py-24 sm:py-32 px-4 sm:px-6 lg:px-8 bg-[#F5F5F5]">
      <div className="max-w-3xl mx-auto">
        <div className="text-center mb-12">
          <h2
            ref={titleRef}
            className="text-3xl sm:text-4xl lg:text-5xl font-black text-[#0A0A0A] mb-4"
            style={{ opacity: 0 }}
          >
            Dúvidas<span className="gradient-text">?</span>
          </h2>
        </div>

        <div
          ref={faqRef}
          className="bg-white rounded-2xl p-4 sm:p-8 card-shadow"
          style={{ opacity: 0 }}
        >
          {faqs.map((faq, index) => (
            <FAQItem
              key={index}
              question={faq.question}
              answer={faq.answer}
              isOpen={openIndex === index}
              onClick={() => setOpenIndex(openIndex === index ? null : index)}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
