# Infraestrutura Terraform

O diretorio `infra/` declara todo o runtime do FargateFlow. O bucket de state, o
provedor OIDC do GitHub e a role compartilhada de automacao sao pre-requisitos da
conta e permanecem fora deste state.

## Inventario

| Arquivo        | Responsabilidade       | Recursos principais                                    |
| -------------- | ---------------------- | ------------------------------------------------------ |
| `network.tf`   | Rede multi-AZ          | VPC, subnets, route tables, IGW e NAT Gateway regional |
| `security.tf`  | Fronteiras de trafego  | Security groups e regras explicitas                    |
| `alb.tf`       | Entrada HTTP           | ALB, listener, target group e health check             |
| `ecr.tf`       | Artefatos de container | Repositorio, scan e lifecycle policy                   |
| `iam.tf`       | Identidades de runtime | Task role e task execution role                        |
| `ecs.tf`       | Computacao e logs      | Cluster, task definition, service e CloudWatch Logs    |
| `providers.tf` | Provider e tags        | AWS provider, identidade e AZs disponiveis             |
| `versions.tf`  | Versoes e backend      | Terraform, AWS provider e state S3                     |

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

## Ownership entre Terraform e CD

| Propriedade                                            | Responsavel |
| ------------------------------------------------------ | ----------- |
| Rede, ALB, ECR, cluster, service base e IAM de runtime | Terraform   |
| Build e publicacao da imagem                           | CD          |
| Revisao ativa da task definition e `desired_count`     | CD          |

O lifecycle do service ignora alteracoes em `task_definition` e `desired_count`. Isso
evita que um futuro `terraform apply` reverta uma versao implantada pelo CD ou reduza
o service novamente para zero.

## State remoto compartilhado

```text
Bucket: terraform-states-761018861028-us-east-1
Key:    fargateflow/study/terraform.tfstate
Lock:   fargateflow/study/terraform.tfstate.tflock
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
