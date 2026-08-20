# Infraestrutura Terraform

O diretorio `infra/` contem o runtime efemero do laboratorio, que pode ser destruido
ao fim do estudo. A identidade OIDC e o backend S3 sao recursos compartilhados da
conta e ficam fora deste state.

## Inventario

| Arquivo            | Responsabilidade       | Recursos principais                                     |
| ------------------ | ---------------------- | ------------------------------------------------------- |
| `network.tf`       | Rede multi-AZ          | VPC, subnets, route tables, IGW e NAT Gateway regional  |
| `security.tf`      | Fronteiras de trafego  | Security groups e regras explicitas                     |
| `alb.tf`           | Entrada HTTP           | ALB, listener, target group e health check              |
| `ecr.tf`           | Artefatos de container | Repositorio, scan e lifecycle policy                    |
| `iam.tf`           | Identidades de runtime | Task role e task execution role                         |
| `ecs.tf`           | Computacao e rollback  | Cluster, task definition, service e rollback automatico |
| `observability.tf` | Sinais operacionais    | Alarmes CloudWatch, dashboard e rollback por `5XX`      |
| `locals.tf`        | Convencoes locais      | Nomes compartilhados dos recursos do laboratorio        |
| `providers.tf`     | Provider e tags        | AWS provider, identidade e AZs disponiveis              |
| `versions.tf`      | Versoes e backend      | Terraform, AWS provider e state S3                      |
| `iam/trust/`       | Trust de runtime       | Template JSON usado pelas roles de task do ECS          |

## Enderecamento

| Camada    | CIDR           | Exposicao                   |
| --------- | -------------- | --------------------------- |
| VPC       | `10.0.0.0/16`  | Rede do projeto             |
| Publica A | `10.0.1.0/24`  | ALB e conectividade publica |
| Publica B | `10.0.2.0/24`  | ALB e conectividade publica |
| Privada A | `10.0.11.0/24` | Tarefas ECS                 |
| Privada B | `10.0.12.0/24` | Tarefas ECS                 |

Nenhuma subnet atribui IPv4 publico automaticamente. O ALB recebe enderecos publicos
por ser `internet-facing`; as tarefas usam ENIs privadas e o NAT para saida.

## ECS

A task definition reserva `0.25 vCPU` e `512 MiB`, usa Linux ARM64, rede `awsvpc` e
porta `3000`. O service distribui tarefas nas subnets privadas, habilita rebalanceamento
entre AZs e rollback automatico pelo deployment circuit breaker.

O primeiro `terraform apply` usa `desired_count = 0`, pois a imagem real ainda nao
existe. Depois que o ECR esta disponivel, o CD publica a imagem, registra uma nova
revisao da task definition e escala o service para duas tarefas.

## Observabilidade e recuperacao

O CloudWatch dashboard `fargateflow-observability` exibe CPU e memoria do service ECS,
quantidade de targets saudaveis ou indisponiveis e respostas `5XX` do ALB. Tres alarmes
avaliam tres periodos consecutivos de um minuto:

- `fargateflow-target-5xx`: cinco ou mais erros `5XX` da aplicacao; integrado ao ECS para
  reverter a revisao em deployment;
- `fargateflow-ecs-cpu-high`: CPU media de pelo menos 80%;
- `fargateflow-ecs-memory-high`: memoria media de pelo menos 80%.

Os dois ultimos alarmes sao sinais operacionais sem acao automatica. Isso permite
investigar capacidade antes de introduzir autoscaling. O deployment circuit breaker ja
protege contra tarefas que nao inicializam ou nao passam nos health checks; o alarme
complementa essa protecao quando a nova versao responde, mas devolve erros ao trafego.

## Ownership entre Terraform e CD

| Propriedade                                            | Responsavel |
| ------------------------------------------------------ | ----------- |
| Rede, ALB, ECR, cluster, service base e IAM de runtime | Terraform   |
| Build e publicacao da imagem                           | CD          |
| Revisao ativa da task definition e `desired_count`     | CD          |

O lifecycle do service ignora alteracoes em `task_definition` e `desired_count`. Isso
evita que um futuro `terraform apply` reverta uma versao implantada pelo CD ou reduza
o service novamente para zero.

## Identidade compartilhada

Terraform, destroy e CD assumem a mesma role `github-actions-deploy-role` via OIDC.
Ela e um recurso compartilhado da conta, fora deste state, e pode ser reutilizada por
outros projetos pessoais nas branches `main`, `develop` e `homolog`.

Como `PowerUserAccess` nao inclui IAM, a policy
`docs/github-actions-fargateflow-runtime-iam-policy.json` complementa a role
compartilhada com permissoes restritas para criar, atualizar e remover somente as duas
roles de runtime do ECS deste laboratorio.

As roles de runtime do ECS continuam em `iam.tf`; seu trust policy tambem e um template
JSON. A task role da API nao recebe nenhuma permissao AWS ate que exista uma dependencia
real que a justifique.

## Gates de ciclo de vida

O bloco `locals` em `locals.tf` contem `provision_infrastructure` e
`destroy_infrastructure`. Os valores sao avaliados pela pipeline somente depois de
`validate` e `plan`:

```text
false -> nao executa apply; nenhum recurso cobravel e criado
true  -> executa apply automatico do runtime
```

Com `destroy_infrastructure=true`, o workflow encadeado `Destroy runtime` cria e aplica
um plano `terraform plan -destroy` para o state `fargateflow/study`. O escopo
o bucket compartilhado, o provedor OIDC e a role compartilhada ficam preservados. As
duas chaves sao mutuamente exclusivas.

Elas nao sao usadas em `count` ou `for_each`. Por isso, alterar para `false` nao pede
a destruicao dos recursos existentes; apenas bloqueia a respectiva operacao automatica.

## State remoto compartilhado

```text
Bucket: terraform-states-761018861028-us-east-1
Runtime key:  fargateflow/study/terraform.tfstate
```

O bucket tem versionamento, criptografia SSE-S3 AES-256, ownership forçado para a
conta, bloqueio integral de acesso publico e policy que exige HTTPS. O lockfile nativo
do backend S3 impede duas operacoes Terraform simultaneas sobre o mesmo state.

Outros projetos devem reutilizar o bucket com uma key exclusiva no formato:

```text
nome-do-projeto/ambiente/terraform.tfstate
```

## Tags

O provider aplica a todos os recursos compativeis:

```text
Project=aws-fargate-infrastructure-lab
Environment=study
ManagedBy=terraform
Owner=kaio
```

Essas tags permitem inventario, filtros de auditoria e analise de custos por projeto.

## Convencoes locais

`providers.tf` centraliza tags comuns com `default_tags`, enquanto `locals.tf` concentra
nomes usados em mais de um recurso, como ALB, cluster, service e security groups. Esse
padrao evita nomes e tags dispersos sem criar modulos Terraform para uma infraestrutura
que ainda pertence a um unico projeto.
