# CI/CD

Tres workflows separam qualidade de codigo, validacao de infraestrutura e entrega.
Actions de terceiros sensiveis estao fixadas por commit SHA para reduzir risco de
alteracao inesperada de dependencias da pipeline.

## Fluxo completo

```mermaid
sequenceDiagram
  actor Dev as Desenvolvedor
  participant GH as GitHub
  participant CI as Workflow CI
  participant TF as Workflow Terraform
  participant Destroy as Workflow Destroy runtime
  participant AWS as AWS via OIDC
  participant ECR as Amazon ECR
  participant ECS as Amazon ECS
  participant ALB as Application Load Balancer

  Dev->>GH: push na main
  GH->>CI: dispara validacao
  CI->>CI: format, lint, test, build
  CI-->>GH: sucesso
  GH->>TF: dispara workflow Terraform
  TF->>AWS: assume role compartilhada por OIDC
  TF->>TF: validate e plan
  alt provision_infrastructure = true
    TF->>AWS: terraform apply do runtime
  else provision_infrastructure = false
    TF->>TF: registra apply bloqueado
  end
  TF-->>GH: sucesso
  GH->>Destroy: dispara workflow de governanca
  alt destroy_infrastructure = true
    Destroy->>AWS: terraform plan -destroy e apply
  else destroy_infrastructure = false
    Destroy->>Destroy: registra destroy bloqueado
  end
  GH->>AWS: workflow CD assume role compartilhada
  AWS-->>GH: credenciais temporarias
  GH->>ECR: build e push ARM64 por commit SHA
  GH->>ECR: aguarda scan HIGH/CRITICAL
  GH->>ECS: registra task definition por digest
  GH->>ECS: atualiza e escala service para 2
  GH->>ALB: GET /health
  ALB-->>GH: 200 {status: ok}
```

## CI

Executa em pushes e pull requests direcionados a `main`:

1. instala Node.js 24 e dependencias com `npm ci`;
2. verifica formatacao com Prettier;
3. executa ESLint;
4. executa testes Vitest;
5. compila TypeScript.

Uma falha impede o acionamento automatico do CD.

## Terraform

Em pull requests, executa `fmt`, inicializacao sem backend e `validate`, sem acessar a
conta AWS. Depois de um CI bem-sucedido na `main`:

1. assume `github-actions-deploy-role` por OIDC e gera o plan do runtime;
2. consulta `provision_infrastructure` e `destroy_infrastructure` em
   `infra/environments/study.tfvars`.

O valor padrao e `false`: o plan continua visivel, mas o job de apply e ignorado. Com
`true`, a pipeline executa um novo plan e aplica o runtime. As duas chaves nao podem
estar em `true` ao mesmo tempo.

## Destroy runtime

Depois de Terraform, o workflow de governanca le `destroy_infrastructure`. Com a
chave em `true`, assume `github-actions-deploy-role`, cria um plano `-destroy` e aplica
o plano do state do runtime. O bucket compartilhado, o provedor OIDC e a role
compartilhada nao pertencem a esse escopo. O CD le a mesma chave e e ignorado quando
ha uma destruicao solicitada.

## CD

O CD inicia depois de um workflow Terraform bem-sucedido na `main` ou por acionamento
manual na mesma branch. Primeiro confirma que ECR e service ECS existem; se a stack
estiver destruida, finaliza com sucesso e registra que o deploy foi ignorado.

Quando a infraestrutura existe:

1. autentica na AWS e no ECR com credenciais temporarias;
2. reutiliza a imagem se o SHA do commit ja estiver publicado;
3. gera uma imagem `linux/arm64` com cache do GitHub Actions;
4. bloqueia a entrega se o scan ECR encontrar severidade `HIGH` ou `CRITICAL`;
5. resolve o digest imutavel da imagem;
6. registra e implanta uma nova task definition;
7. aguarda estabilidade e escala o service para duas tarefas;
8. valida `GET /health` pelo DNS publico do ALB;
9. escreve commit, imagem, task definition, service e resultado no job summary.

O upload do build record `.dockerbuild` esta desabilitado. A pipeline mantem apenas o
resumo legivel do build e do deploy.

## Identidade

Os workflows solicitam `id-token: write` somente nos jobs que acessam a AWS. Terraform,
destroy e CD assumem a role compartilhada `github-actions-deploy-role`. Sua trust policy
limita a organizacao GitHub e as branches permitidas. O account ID e mascarado pelas
actions; nomes de recursos, commit SHA e digests exibidos no summary sao metadados
operacionais, nao segredos.
