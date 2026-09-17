Add-Type -AssemblyName System.Speech

function Generate-Voiceover($text, $outputPath, $rate = 1) {
    $synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
    $synth.SelectVoice("Microsoft Maria Desktop")
    $synth.Rate = $rate
    $synth.SetOutputToWaveFile($outputPath)
    $synth.Speak($text)
    $synth.Dispose()
    Write-Host "Generated audio: $outputPath"
}

$textLandscape = "Apresentamos o NekoCast: a sua central definitiva de animes e mangás na palma da mão! Explore um catálogo ilimitado com lançamentos da temporada, recomendações populares e integração com as melhores fontes da web. Assista em Full HD com um player ultra responsivo e o recurso exclusivo AniSkip, que detecta e pula aberturas automaticamente. Gosta de leitura? O leitor de mangás integrado oferece navegação vertical fluida e sincronização com o MangaDex. Baixe episódios para assistir offline em qualquer lugar. Disponível para Android, Windows, Web, Linux e iOS. Livre de anúncios invasivos e totalmente gratuito. Baixe o NekoCast hoje mesmo e transforme sua experiência otaku!"

$textShorts = "Cansado de apps travando e cheios de anúncios toda vez que você quer assistir anime? Conheça o NekoCast! Milhares de animes em alta definição, múltiplas fontes e temporadas atualizadas em tempo real. E o melhor: com o AniSkip, você pula aberturas e encerramentos com apenas um toque! Além disso, leia seus mangás favoritos e baixe episódios completos para assistir offline onde quiser. Cem por cento gratuito e de código aberto. Baixe o NekoCast agora pelo link na descrição!"

$publicDir = "c:\Users\user\Desktop\NekoCast\remotion\public"

Generate-Voiceover $textLandscape "$publicDir\voiceover_landscape.wav" 1
Generate-Voiceover $textShorts "$publicDir\voiceover_shorts.wav" 2
