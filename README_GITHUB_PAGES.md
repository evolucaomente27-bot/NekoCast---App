# 🚀 NekoCast no GitHub Pages (100% Gratuito, Serverless & Sem Servidor)

O site do sistema do **NekoCast** foi adaptado para rodar nativamente no **GitHub Pages** sem precisar de nenhum servidor (Node.js, Discloud, VPS, etc.). Tudo é executado diretamente no navegador do usuário utilizando APIs públicas com CORS e persistência local.

---

## 🌟 O que está incluído no Site

1. **Apresentação Oficial do NekoCast**:
   - Visual moderno em tema escuro com detalhes em laranja.
   - Animações fluidas, estatísticas, prévias dos recursos e perguntas frequentes.
   - Botões diretos para download do **Android APK (v1.0.5)** e **Windows ZIP (v1.0.5)**.

2. **Sistema Web Interativo (Web App)**:
   - **Catálogo de Animes**: Animes da temporada atual, mais populares e filtros por gênero via API aberta da *Jikan Moe*.
   - **Busca Instantânea**: Pesquise qualquer título em tempo real.
   - **Detalhes & Trailers**: Sinopses, pontuações, notas e reprodução de trailers oficiais em HD do YouTube.
   - **Leitor de Mangás**: Integração direta com a API do *MangaDex* com leitor de capítulos integrado no navegador (avançar página, zoom, tela cheia).
   - **Minha Lista (Favoritos)**: Salve seus animes e mangás favoritos persistidos diretamente no `localStorage` do seu navegador.
   - **Flutter Web Completo**: Acesse a versão compilada em `/app/index.html`.

---

## ⚡ Como Publicar no GitHub Pages (Passo a Passo)

### Método Automático via GitHub Actions (Recomendado)

O repositório já inclui o arquivo de automação [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml). Para ativá-lo:

1. **Faça o commit e push das alterações para o GitHub**:
   ```bash
   git add .
   git commit -m "Publica site do sistema NekoCast para GitHub Pages"
   git push origin master
   ```

2. **Ative o GitHub Pages no seu repositório**:
   - Acesse o repositório no GitHub: `https://github.com/evolucaomente27-bot/NekoCast---App`
   - Clique na aba **Settings** (Configurações) no topo.
   - No menu lateral esquerdo, clique em **Pages**.
   - Na seção **Build and deployment**:
     - Em **Source**, selecione **GitHub Actions**.
   - Pronto! O workflow será executado automaticamente a cada push na branch `master` e publicará o site.

3. **Acesse o seu site**:
   O endereço será:
   ```
   https://evolucaomente27-bot.github.io/NekoCast---App/
   ```

---

## 🧪 Como Testar Localmente

Para rodar o site no seu computador antes de enviar ao GitHub:

```bash
# Iniciar o servidor de desenvolvimento
npm run dev

# Ou gerar o build e pré-visualizar
npm run build
npm run preview
```

O terminal exibirá o link local (ex: `http://localhost:3000/`) para você navegar e testar todas as funcionalidades.
