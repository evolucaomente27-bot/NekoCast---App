import { useEffect, useRef } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { MessageCircle, Twitter, Send, Github, Heart } from 'lucide-react';

gsap.registerPlugin(ScrollTrigger);

const quickLinks = [
  { label: 'Inicio', href: '#hero' },
  { label: 'Recursos', href: '#recursos' },
  { label: 'Mangá', href: '#manga' },
  { label: 'Como Funciona', href: '#como-funciona' },
  { label: 'Previa', href: '#previa' },
  { label: 'Duvidas', href: '#faq' },
];

const legalLinks = [
  { label: 'Termos de Uso', href: '#' },
  { label: 'Politica de Privacidade', href: '#' },
];

const socialLinks = [
  { icon: MessageCircle, href: '#', label: 'Discord' },
  { icon: Twitter, href: '#', label: 'Twitter' },
  { icon: Send, href: '#', label: 'Telegram' },
  { icon: Github, href: '#', label: 'GitHub' },
];

export default function Footer() {
  const footerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (contentRef.current) {
        const columns = contentRef.current.children;
        gsap.fromTo(
          columns,
          { opacity: 0, y: 30 },
          {
            opacity: 1,
            y: 0,
            duration: 0.6,
            stagger: 0.1,
            ease: 'power3.out',
            scrollTrigger: {
              trigger: footerRef.current,
              start: 'top 90%',
            },
          }
        );
      }
    }, footerRef);

    return () => ctx.revert();
  }, []);

  const scrollTo = (href: string) => {
    if (href === '#') return;
    const element = document.querySelector(href);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth' });
    }
  };

  return (
    <footer id="footer" ref={footerRef} className="bg-[#0A0A0A] pt-16 sm:pt-20 pb-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto">
        <div
          ref={contentRef}
          className="grid grid-cols-2 md:grid-cols-4 gap-8 lg:gap-12 mb-12"
        >
          {/* Brand */}
          <div className="col-span-2 md:col-span-1" style={{ opacity: 0 }}>
            <div className="flex items-center gap-2 mb-4">
              <img
                src="https://i.imgur.com/cEVu3Fs.png"
                alt="NekoCast"
                className="w-10 h-10 object-contain"
              />
              <span className="font-bold text-xl text-white">
                Neko<span className="text-[#FF6B1A]">Cast</span>
              </span>
            </div>
            <p className="text-white/60 text-sm mb-6 leading-relaxed">
              Seu portal para animes e mangás com estilo
            </p>
            <div className="flex gap-3">
              {socialLinks.map((social, index) => (
                <a
                  key={index}
                  href={social.href}
                  aria-label={social.label}
                  className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center text-white/60 hover:bg-[#FF6B1A] hover:text-white transition-all duration-300"
                >
                  <social.icon className="w-4 h-4" />
                </a>
              ))}
            </div>
          </div>

          {/* Quick Links */}
          <div style={{ opacity: 0 }}>
            <h4 className="font-semibold text-white mb-4">Links Rapidos</h4>
            <ul className="space-y-3">
              {quickLinks.map((link, index) => (
                <li key={index}>
                  <button
                    onClick={() => scrollTo(link.href)}
                    className="text-sm text-white/60 hover:text-[#FF6B1A] transition-colors duration-200"
                  >
                    {link.label}
                  </button>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div style={{ opacity: 0 }}>
            <h4 className="font-semibold text-white mb-4">Legal</h4>
            <ul className="space-y-3">
              {legalLinks.map((link, index) => (
                <li key={index}>
                  <a
                    href={link.href}
                    className="text-sm text-white/60 hover:text-[#FF6B1A] transition-colors duration-200"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Contact */}
          <div style={{ opacity: 0 }}>
            <h4 className="font-semibold text-white mb-4">Contato</h4>
            <p className="text-sm text-white/60 mb-4">
              suporte@nekocast.app
            </p>
            <a
              href="#"
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-[#5865F2] text-white text-sm font-medium rounded-lg hover:bg-[#4752C4] transition-colors duration-200"
            >
              <MessageCircle className="w-4 h-4" />
              Entrar no Discord
            </a>
          </div>
        </div>

        {/* Bottom bar */}
        <div className="border-t border-white/10 pt-8 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-sm text-white/40 text-center sm:text-left">
            &copy; 2025 NekoCast. Todos os direitos reservados.
          </p>
          <p className="text-sm text-white/40 flex items-center gap-1">
            Feito com <Heart className="w-3 h-3 text-[#FF6B1A] fill-[#FF6B1A]" /> por fãs de anime para fãs de anime
          </p>
        </div>
      </div>
    </footer>
  );
}
