# Aplicacao e container

O codigo de negocio e propositalmente pequeno. O objetivo e fornecer um workload
real e verificavel sem esconder os conceitos de infraestrutura em camadas de
aplicacao desnecessarias.

## API

| Metodo | Rota      | Resposta                                    | Uso                           |
| ------ | --------- | ------------------------------------------- | ----------------------------- |
| `GET`  | `/`       | `{ "name": "FargateFlow", "status": "ok" }` | Identificacao da API          |
| `GET`  | `/health` | `{ "status": "ok" }`                        | Docker, ECS, ALB e smoke test |

O `buildApp()` cria a instancia Fastify e permite testes por injecao sem abrir uma
porta real. O servidor e iniciado separadamente em `src/server.ts`.

## Configuracao

A configuracao e validada com Zod antes de o servidor iniciar.

| Variavel    | Padrao        | Valores aceitos                          |
| ----------- | ------------- | ---------------------------------------- |
| `NODE_ENV`  | `development` | `development`, `test`, `production`      |
| `HOST`      | `0.0.0.0`     | String nao vazia                         |
| `PORT`      | `3000`        | Inteiro entre `1` e `65535`              |
| `LOG_LEVEL` | `info`        | Niveis suportados pelo logger do Fastify |

Uma configuracao invalida encerra o processo antes de aceitar trafego. O arquivo
`.env.example` documenta os valores para desenvolvimento, mas a aplicacao nao carrega
arquivos `.env` automaticamente.

## Logs e erros

O logger Pino integrado ao Fastify escreve logs estruturados em JSON no stdout. No
ECS, o driver `awslogs` encaminha essa saida ao CloudWatch. O error handler registra
o erro completo internamente e evita expor detalhes inesperados em respostas `5xx`.

## Encerramento gracioso

O processo trata `SIGTERM` e `SIGINT`. Ao receber um sinal, bloqueia chamadas de
shutdown duplicadas, fecha o Fastify e encerra com codigo `0`; uma falha durante o
fechamento resulta em codigo `1`.

No ECS, a task definition oferece ate 30 segundos (`stopTimeout`) para o processo
finalizar. O target group tambem usa 30 segundos de deregistration delay para drenar
conexoes durante uma substituicao de tarefas.

## Imagem Docker

O Dockerfile usa Node.js 24 Alpine e quatro estagios:

1. `dependencies`: instala dependencias completas com `npm ci`.
2. `build`: compila TypeScript para JavaScript.
3. `production-dependencies`: instala apenas dependencias de runtime.
4. `runtime`: recebe somente build, dependencias de producao e metadados essenciais.

A imagem final roda como usuario `node`, usa filesystem raiz somente leitura no ECS
e possui health check interno sem instalar `curl`. O CD gera exclusivamente a
plataforma `linux/arm64`.

## Desenvolvimento e testes

```powershell
npm ci
npm run dev
```

Validacao equivalente ao CI:

```powershell
npm run format:check
npm run lint
npm test
npm run build
```

Os testes Vitest verificam as duas rotas, valores padrao, coercao e rejeicao de
variaveis de ambiente invalidas.
