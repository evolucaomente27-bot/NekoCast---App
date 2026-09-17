import { useState, useEffect } from 'react';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import Lenis from 'lenis';

import Navigation from './sections/Navigation';
import HeroSection from './sections/HeroSection';
import StatsSection from './sections/StatsSection';
import FeaturesSection from './sections/FeaturesSection';
import MangaSection from './sections/MangaSection';
import HowItWorksSection from './sections/HowItWorksSection';
import AppPreviewSection from './sections/AppPreviewSection';
import TestimonialsSection from './sections/TestimonialsSection';
import FAQSection from './sections/FAQSection';
import CTASection from './sections/CTASection';
import Footer from './sections/Footer';
import SystemContainer from './components/system/SystemContainer';

gsap.registerPlugin(ScrollTrigger);

type SystemTab = 'animes' | 'mangas' | 'favorites' | 'downloads';

function App() {
  const [isSystemMode, setIsSystemMode] = useState(false);
  const [systemTab, setSystemTab] = useState<SystemTab>('animes');

  useEffect(() => {
    if (isSystemMode) return; // Lenis só na Landing Page

    // Initialize Lenis smooth scroll
    const lenis = new Lenis({
      duration: 1.2,
      easing: (t) => Math.min(1, 1.001 - Math.pow(2, -10 * t)),
      orientation: 'vertical',
      gestureOrientation: 'vertical',
      smoothWheel: true,
      touchMultiplier: 2,
    });

    // Connect Lenis to GSAP ScrollTrigger
    lenis.on('scroll', ScrollTrigger.update);

    gsap.ticker.add((time) => {
      lenis.raf(time * 1000);
    });

    gsap.ticker.lagSmoothing(0);

    // Refresh ScrollTrigger after images load
    const images = document.querySelectorAll('img');
    let loadedCount = 0;
    const totalImages = images.length;

    const checkAllLoaded = () => {
      loadedCount++;
      if (loadedCount >= totalImages) {
        ScrollTrigger.refresh();
      }
    };

    images.forEach((img) => {
      if (img.complete) {
        checkAllLoaded();
      } else {
        img.addEventListener('load', checkAllLoaded);
        img.addEventListener('error', checkAllLoaded);
      }
    });

    // Fallback refresh after 3 seconds
    const refreshTimeout = setTimeout(() => {
      ScrollTrigger.refresh();
    }, 3000);

    return () => {
      lenis.destroy();
      clearTimeout(refreshTimeout);
      ScrollTrigger.getAll().forEach((st) => st.kill());
    };
  }, [isSystemMode]);

  const handleOpenSystem = (tab: SystemTab = 'animes') => {
    setSystemTab(tab);
    setIsSystemMode(true);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  const handleBackToLanding = () => {
    setIsSystemMode(false);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <div className="relative bg-[#0A0A0A] min-h-screen">
      <Navigation onOpenSystem={handleOpenSystem} isSystemMode={isSystemMode} />

      {isSystemMode ? (
        <main>
          <SystemContainer onBackToLanding={handleBackToLanding} initialTab={systemTab} />
        </main>
      ) : (
        <main>
          <HeroSection onOpenSystem={handleOpenSystem} />
          <StatsSection />
          <FeaturesSection />
          <MangaSection onOpenSystem={handleOpenSystem} />
          <HowItWorksSection />
          <AppPreviewSection />
          <TestimonialsSection />
          <FAQSection />
          <CTASection />
        </main>
      )}

      <Footer />
    </div>
  );
}

export default App;
