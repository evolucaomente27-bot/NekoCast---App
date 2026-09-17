# Guia de Implantação 100% Discloud (Full-Stack 1GB RAM)

Este projeto foi configurado como **Full-Stack único (Frontend Web + Backend API)** hospedado exclusivamente na **Discloud** com **1024MB (1GB) de RAM**. Não é necessário utilizar Netlify nem qualquer outro serviço externo.

---

## ⚡ Como funciona a Aplicação Full-Stack na Discloud

Um único aplicativo hospedado na Discloud executa o servidor Node.js (`server/index.js`), que é responsável por:
1. **Entregar o Frontend Web** (`build/web`) diretamente no seu domínio Discloud (`https://seu-app.discloud.app/`).
2. **Fornecer as APIs REST e Proxy CORS** no prefixo `/api/` (ex: `/health`, `/api/proxy`, `/api/animefire/search`, `/api/allanime/search`).

---

## 📦 Arquivo `discloud.config` (Na Raiz do Projeto)

```ini
ID=nekocast
TYPE=site
MAIN=server/index.js
NAME=NekoCast Full App
RAM=1024
AUTORESTART=true
VERSION=latest
```

---

## 🚀 Passo a Passo para Fazer Upload na Discloud

### Opção 1: Pelo Painel Web da Discloud (Mais Simples)
1. Certifique-se de que a pasta `build/web` existe (se necessário, rode `flutter build web --release`).
2. Selecione e compacte os seguintes itens da raiz em um arquivo **`.zip`**:
   - `discloud.config`
   - pasta `server/`
   - pasta `build/web/`
3. Acesse o painel da Discloud: [https://discloud.app/dashboard](https://discloud.app/dashboard)
4. Clique em **"Adicionar Aplicação"** (Add Application) e envie o arquivo `.zip`.
5. Pronto! Seu aplicativo Full-Stack estará online em `https://nekocast.discloud.app`.

### Opção 2: Via Extensão Discloud no VS Code
1. Instale a extensão oficial **Discloud** no VS Code.
2. Abra o projeto no VS Code.
3. Clique com o botão direito no arquivo `discloud.config` da raiz do projeto e selecione **"Upload to Discloud"**.

---

## 🧪 Como Testar Tudo Localmente Antes do Upload

Para rodar localmente o servidor Full-Stack idêntico ao da Discloud:

```bash
# 1. Gerar os arquivos do Flutter Web (se ainda não gerou)
flutter build web --release

# 2. Iniciar o servidor Node.js
cd server
npm start
```

Acesse no seu navegador:
- **Interface do App Web**: `http://localhost:8080/`
- **Métricas de RAM (1GB) e Status**: `http://localhost:8080/health`
- **API de Busca**: `http://localhost:8080/api/animefire/search?q=naruto`
