# NekoCast

Aplicativo Flutter para descobrir, acompanhar e assistir animes, além de pesquisar mangás e ler capítulos em dispositivos móveis e desktop.

> **Status:** projeto em desenvolvimento. Algumas fontes externas podem ficar indisponíveis ou mudar de formato sem aviso.

## Funcionalidades

- Página inicial com destaques, temporadas, gêneros e animes populares.
- Busca de animes e histórico de pesquisas.
- Seleção entre fontes de conteúdo disponíveis.
- Lista de episódios com reprodução de vídeo.
- Controles de pular abertura e encerramento quando há dados disponíveis.
- Lista de acompanhamento (watchlist) persistida localmente.
- Downloads de episódios para assistir offline, com pausa, retomada e controle de qualidade.
- Catálogo de mangás, capítulos, leitor e downloads.
- Tema claro/escuro e interface em português ou inglês.
- Layout responsivo para diferentes tamanhos de tela.

## Tecnologias

- [Flutter](https://flutter.dev/) e Dart.
- `provider` para gerenciamento de estado.
- `sqflite` e `shared_preferences` para persistência local.
- `video_player` e `chewie` para reprodução.
- `http` e `html` para comunicação e processamento de fontes.
- `cached_network_image` para cache de imagens.

## Fontes e serviços externos

O aplicativo integra serviços públicos para metadados, imagens, episódios e mangás, incluindo Jikan/MyAnimeList, AniList, AniSkip, AllAnime, MangaDex, Kitsu e TMDB.

A disponibilidade e os termos dessas fontes podem mudar. O projeto não hospeda nem distribui conteúdo protegido por direitos autorais. Use o aplicativo somente de acordo com as leis e os termos aplicáveis à sua região.

## Requisitos

- Flutter SDK compatível com Dart `^3.9.2`.
- Git.
- Android Studio e Android SDK para Android.
- Xcode em um Mac para iOS/macOS.
- Um dispositivo físico ou emulador configurado.

Confira o ambiente com:

```bash
flutter doctor
```

## Instalação

```bash
git clone https://github.com/evolucaomente27-bot/NekoCast---App.git
cd NekoCast---App
flutter pub get
```

O TMDB é opcional. Para habilitar thumbnails adicionais, forneça a chave
somente no ambiente local:

```bash
flutter run --dart-define=TMDB_API_KEY=sua_chave
```

Não coloque chaves de API diretamente no código ou no repositório.

## Executar em desenvolvimento

```bash
# Lista os dispositivos disponíveis
flutter devices

# Executa no dispositivo padrão
flutter run

# Executa em um dispositivo específico
flutter run -d <device_id>
```

## Verificação do projeto

```bash
flutter analyze
flutter test
```

## Builds

### Android APK

```bash
flutter build apk --release
```

Saída padrão: `build/app/outputs/flutter-apk/app-release.apk`.

Para gerar um pacote para a Google Play:

```bash
flutter build appbundle --release
```

### iOS

Requer macOS, Xcode, assinatura e configuração de um Apple Developer Account:

```bash
flutter build ipa --release
```

### Web, Windows, Linux e macOS

```bash
flutter build web --release
flutter build windows --release
flutter build linux --release
flutter build macos --release
```

## Estrutura principal

```text
lib/
├── models/       # Modelos de dados
├── screens/      # Telas e fluxos de navegação
├── services/     # APIs, banco local, downloads e preferências
├── theme/        # Cores e tema do aplicativo
├── utils/        # Utilitários compartilhados
└── widgets/      # Componentes reutilizáveis
```

## Contribuição

1. Crie uma branch para sua alteração:

   ```bash
   git checkout -b feature/minha-alteracao
   ```

2. Faça as mudanças e execute `flutter analyze` e `flutter test`.
3. Crie um commit descritivo.
4. Abra um Pull Request explicando o problema e a solução.

## Licença

Este projeto está disponível sob a licença MIT. Consulte [LICENSE](LICENSE).

## Suporte

Ao relatar um problema, inclua:

- sistema operacional e versão;
- versão do Flutter (`flutter --version`);
- dispositivo ou emulador usado;
- mensagem de erro e passos para reproduzir;
- screenshots ou logs relevantes, quando possível.
