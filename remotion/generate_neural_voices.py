import asyncio
import edge_tts
import os

TEXT_LANDSCAPE = """Apresentamos o NekoCast: a sua central definitiva de animes e mangás na palma da mão!
Explore um catálogo ilimitado com lançamentos da temporada, recomendações populares e integração com as melhores fontes da web.
Assista em Full HD com um player ultra responsivo e o recurso exclusivo AniSkip, que detecta e pula aberturas automaticamente.
Gosta de leitura? O leitor de mangás integrado oferece navegação vertical fluida e sincronização com o MangaDex.
Baixe episódios para assistir offline em qualquer lugar. Disponível para Android, Windows, Web, Linux e iOS.
Livre de anúncios invasivos e totalmente gratuito. Baixe o NekoCast hoje mesmo e transforme sua experiência otaku!"""

TEXT_SHORTS = """Cansado de apps travando e cheios de anúncios toda vez que você quer assistir anime? Conheça o NekoCast!
Milhares de animes em alta definição, múltiplas fontes e temporadas atualizadas em tempo real.
E o melhor: com o AniSkip, você pula aberturas e encerramentos com apenas um toque!
Além disso, leia seus mangás favoritos e baixe episódios completos para assistir offline onde quiser.
Cem por cento gratuito e de código aberto. Baixe o NekoCast agora pelo link na descrição!"""

VOICE = "pt-BR-AntonioNeural" # Voz neural brasileira masculina enérgica e profissional

async def generate_audio():
    out_dir = os.path.join(os.path.dirname(__file__), "public")
    os.makedirs(out_dir, exist_ok=True)

    print(f"Generating neural voice for Landscape video using {VOICE}...")
    landscape_file = os.path.join(out_dir, "voiceover_landscape.mp3")
    communicate_landscape = edge_tts.Communicate(TEXT_LANDSCAPE, VOICE, rate="+6%", pitch="+0Hz")
    await communicate_landscape.save(landscape_file)
    print(f"Saved: {landscape_file}")

    print(f"Generating neural voice for YouTube Shorts video using {VOICE}...")
    shorts_file = os.path.join(out_dir, "voiceover_shorts.mp3")
    communicate_shorts = edge_tts.Communicate(TEXT_SHORTS, VOICE, rate="+10%", pitch="+0Hz")
    await communicate_shorts.save(shorts_file)
    print(f"Saved: {shorts_file}")

if __name__ == "__main__":
    asyncio.run(generate_audio())
