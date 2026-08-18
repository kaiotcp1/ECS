# syntax=docker/dockerfile:1

# Centraliza a versao do Node.js usada pela imagem.
# Isso facilita trocar a versao no futuro e tambem permite sobrescrever o valor no CI/CD
# com `docker build --build-arg NODE_VERSION=...`, sem editar o Dockerfile.
ARG NODE_VERSION=24

# Estagio 1: instala todas as dependencias do projeto.
# O `npm ci` usa o package-lock.json como fonte da verdade e falha se ele estiver
# inconsistente com o package.json. Isso torna o build mais reproduzivel do que
# `npm install`, que pode atualizar o lockfile.
#
# Aqui instalamos tambem as devDependencies porque o build TypeScript depende de
# ferramentas como `typescript`. Essas dependencias nao entram diretamente na imagem final.
FROM node:${NODE_VERSION}-bookworm-slim AS dependencies
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# Estagio 2: compila a aplicacao TypeScript.
# Este estagio reutiliza o node_modules completo do estagio anterior e copia apenas
# os arquivos necessarios para gerar o build. O resultado esperado e o JavaScript
# compilado dentro de `dist/`.
#
# Separar build de runtime evita levar compilador TypeScript, testes, ESLint e outras
# ferramentas de desenvolvimento para a imagem que vai rodar em producao.
FROM dependencies AS build
WORKDIR /app

COPY tsconfig.json vitest.config.ts eslint.config.js .prettierrc ./
COPY src ./src
COPY test ./test

RUN npm run build

# Estagio 3: instala somente dependencias de producao.
# Mesmo ja existindo um node_modules no estagio `dependencies`, criamos outro aqui com
# `npm ci --omit=dev` para remover tudo que so e necessario em desenvolvimento.
#
# Isso reduz o tamanho da imagem final e diminui a superficie de ataque, porque menos
# pacotes e ferramentas ficam disponiveis dentro do container em execucao.
FROM node:${NODE_VERSION}-bookworm-slim AS production-dependencies
WORKDIR /app

ENV NODE_ENV=production

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Estagio 4: imagem final de runtime.
# Esta e a unica imagem que sera executada. Ela recebe apenas:
# - node_modules com dependencias de producao;
# - JavaScript compilado em `dist/src`;
# - package.json para metadados basicos do projeto.
#
# O codigo TypeScript original, testes, configs de lint e dependencias de desenvolvimento
# nao precisam existir no container final.
FROM node:${NODE_VERSION}-bookworm-slim AS runtime
WORKDIR /app

# Define valores padrao para execucao em container.
# `NODE_ENV=production` ativa o comportamento de producao das dependencias Node.
# `HOST=0.0.0.0` e necessario para o servidor aceitar conexoes vindas de fora do
# container. Se usasse 127.0.0.1, a aplicacao poderia ficar acessivel apenas dentro
# do proprio container.
# `PORT=3000` segue o padrao validado pela configuracao da aplicacao.
#
# Esses valores podem ser sobrescritos por `docker run -e`, ECS Task Definition ou CI/CD.
ENV NODE_ENV=production
ENV HOST=0.0.0.0
ENV PORT=3000

COPY --from=production-dependencies /app/node_modules ./node_modules
COPY --from=build /app/dist/src ./dist/src
COPY package.json ./

# `EXPOSE` documenta a porta que a aplicacao usa dentro do container.
# Ele nao publica a porta sozinho. No Docker local, a publicacao acontece com `-p 3000:3000`.
# No ECS/Fargate, a porta sera usada na definicao do container, target group e health check.
EXPOSE 3000

# Health check interno do container.
# Ele chama o mesmo endpoint `/health` que sera usado depois pelo Target Group do ALB.
# Se a resposta nao for 2xx, o comando sai com codigo 1 e o container fica marcado
# como unhealthy.
#
# Node.js 24 ja possui `fetch` nativo, entao nao precisamos instalar `curl` ou `wget`
# apenas para checar a saude da aplicacao.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:' + (process.env.PORT || 3000) + '/health').then((response) => { if (!response.ok) process.exit(1); }).catch(() => process.exit(1));"

# Executa o processo como usuario sem privilegios.
# A imagem oficial do Node ja fornece o usuario `node`, evitando rodar a aplicacao
# como root dentro do container. Isso segue o principio do menor privilegio.
USER node

# Comando principal do container.
# Executa o JavaScript compilado, nao o TypeScript original.
CMD ["node", "dist/src/server.js"]
