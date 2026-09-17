import { Download, Monitor, Smartphone, Globe, ShieldCheck, Zap, Sparkles } from 'lucide-react';

export default function DownloadsView() {
  const androidApkUrl = 'https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast-1.0.5.apk';
  const windowsZipUrl = 'https://github.com/evolucaomente27-bot/NekoCast---App/releases/download/NekoCast/nekocast_windows-1.0.5.zip';

  return (
    <div className="w-full max-w-5xl mx-auto">
      <div className="text-center mb-10">
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-[#FF6B1A]/10 border border-[#FF6B1A]/30 text-xs font-semibold text-[#FF6B1A] mb-3">
          <Sparkles className="w-3.5 h-3.5" />
          Versão Oficial 1.0.5
        </span>
        <h2 className="text-2xl sm:text-3xl font-black text-white mb-2">
          Baixe o NekoCast para o seu <span className="gradient-text">Dispositivo</span>
        </h2>
        <p className="text-sm sm:text-base text-white/60 max-w-xl mx-auto">
          Instale o aplicativo nativo para Android e Windows para reprodução com aceleração de hardware e downloads offline.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
        {/* Card Android */}
        <div className="bg-[#141414] rounded-2xl p-6 border border-white/10 hover:border-[#FF6B1A]/50 transition-all duration-300 flex flex-col justify-between shadow-xl">
          <div>
            <div className="w-12 h-12 rounded-xl bg-[#FF6B1A]/10 border border-[#FF6B1A]/20 flex items-center justify-center mb-4">
              <Smartphone className="w-6 h-6 text-[#FF6B1A]" />
            </div>
            <h3 className="text-lg font-bold text-white mb-1">Android APK</h3>
            <p className="text-xs text-white/50 mb-4">
              Compatível com Android 7.0 ou superior (Smartphones, Tablets e Android TV).
            </p>

            <ul className="space-y-2 text-xs text-white/70 mb-6">
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Suporte a controle remoto e TV Box
              </li>
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Download de episódios offline
              </li>
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Pular abertura (AniSkip automático)
              </li>
            </ul>
          </div>

          <div>
            <div className="text-[11px] text-white/40 mb-2 flex justify-between">
              <span>Tamanho: ~69 MB</span>
              <span>v1.0.5</span>
            </div>
            <a
              href={androidApkUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-[#FF6B1A] hover:bg-[#ff7b33] text-white font-semibold text-sm transition-all shadow-lg shadow-[#FF6B1A]/20"
            >
              <Download className="w-4 h-4" />
              Baixar APK Direto
            </a>
          </div>
        </div>

        {/* Card Windows */}
        <div className="bg-[#141414] rounded-2xl p-6 border border-white/10 hover:border-[#FFB800]/50 transition-all duration-300 flex flex-col justify-between shadow-xl">
          <div>
            <div className="w-12 h-12 rounded-xl bg-[#FFB800]/10 border border-[#FFB800]/20 flex items-center justify-center mb-4">
              <Monitor className="w-6 h-6 text-[#FFB800]" />
            </div>
            <h3 className="text-lg font-bold text-white mb-1">Windows Desktop</h3>
            <p className="text-xs text-white/50 mb-4">
              Windows 10 e Windows 11 (64-bit). Não requer instalação, pronto para rodar.
            </p>

            <ul className="space-y-2 text-xs text-white/70 mb-6">
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Aceleração por hardware MPV/VLC
              </li>
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Atalhos de teclado configurados
              </li>
              <li className="flex items-center gap-2">
                <ShieldCheck className="w-4 h-4 text-emerald-400 shrink-0" />
                Modo tela cheia sem bordas
              </li>
            </ul>
          </div>

          <div>
            <div className="text-[11px] text-white/40 mb-2 flex justify-between">
              <span>Tamanho: ~35 MB</span>
              <span>v1.0.5</span>
            </div>
            <a
              href={windowsZipUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-white/10 hover:bg-white/20 border border-white/20 text-white font-semibold text-sm transition-all"
            >
              <Download className="w-4 h-4" />
              Baixar Windows .ZIP
            </a>
          </div>
        </div>

        {/* Card Web App Flutter */}
        <div className="bg-[#141414] rounded-2xl p-6 border border-white/10 hover:border-white/30 transition-all duration-300 flex flex-col justify-between shadow-xl">
          <div>
            <div className="w-12 h-12 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-center justify-center mb-4">
              <Globe className="w-6 h-6 text-blue-400" />
            </div>
            <h3 className="text-lg font-bold text-white mb-1">Flutter Web Completo</h3>
            <p className="text-xs text-white/50 mb-4">
              Versão compilada nativa do Flutter Web rodando diretamente em seu navegador.
            </p>

            <ul className="space-y-2 text-xs text-white/70 mb-6">
              <li className="flex items-center gap-2">
                <Zap className="w-4 h-4 text-blue-400 shrink-0" />
                Interface idêntica ao aplicativo móvel
              </li>
              <li className="flex items-center gap-2">
                <Zap className="w-4 h-4 text-blue-400 shrink-0" />
                Execução 100% estática no Netlify
              </li>
              <li className="flex items-center gap-2">
                <Zap className="w-4 h-4 text-blue-400 shrink-0" />
                Sem downloads adicionais
              </li>
            </ul>
          </div>

          <div>
            <div className="text-[11px] text-white/40 mb-2 flex justify-between">
              <span>Acesso Web</span>
              <span>Zero Servidor</span>
            </div>
            <a
              href="/app/index.html"
              target="_blank"
              rel="noopener noreferrer"
              className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl bg-blue-600/80 hover:bg-blue-600 text-white font-semibold text-sm transition-all shadow-lg shadow-blue-500/20"
            >
              <Globe className="w-4 h-4" />
              Abrir Flutter Web
            </a>
          </div>
        </div>
      </div>

      {/* Como Instalar */}
      <div className="bg-white/5 rounded-2xl p-6 border border-white/5 text-xs text-white/60 space-y-3">
        <h4 className="text-sm font-semibold text-white">Instruções de Instalação:</h4>
        <p>
          <strong className="text-white">Android:</strong> Baixe o arquivo APK e abra-o. Se solicitado, permita a instalação a partir desta fonte nas configurações de segurança do seu Android.
        </p>
        <p>
          <strong className="text-white">Windows:</strong> Extraia o arquivo .ZIP para qualquer pasta (ex: Documentos ou Área de Trabalho) e execute o arquivo <code className="bg-white/10 px-1 py-0.5 rounded text-white">nekocast.exe</code>.
        </p>
      </div>
    </div>
  );
}
