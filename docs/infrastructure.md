# Infraestrutura Terraform

O diretorio `infra/` contem duas raizes Terraform com ownership distinto. A identidade
permanece para permitir novas execucoes da pipeline; o runtime e efemero e pode ser
destruido ao fim do laboratorio.

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
| `identity/`    | Identidade de CI/CD    | Roles OIDC, trust policies e permissions policies      |
| `iam/trust/`   | Trust de runtime       | Template JSON usado pelas roles de task do ECS         |

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

## Identidade automatizada

`infra/identity` e aplicada automaticamente depois de um CI bem-sucedido na `main`.
Ela recebe uma credencial temporaria da role compartilhada apenas para garantir duas
roles de aplicacao:

| Role                         | Uso                      | Limite                                               |
| ---------------------------- | ------------------------ | ---------------------------------------------------- |
| `fargateflow-terraform-role` | Plan e apply do runtime  | Repositorio `kaiotcp1/ECS`, branch `main`            |
| `fargateflow-deploy-role`    | Push no ECR e deploy ECS | Repositorio `kaiotcp1/ECS`, environment `production` |

As policies de permissao e de confianca sao arquivos JSON separados em
`identity/policy` e `identity/trust`. Arquivos com extensao `.json.tftpl` recebem
somente os valores dinamicos necessarios, como account ID, regiao e repositorio.

As roles de runtime do ECS continuam em `iam.tf`; seu trust policy tambem e um template
JSON. A task role da API nao recebe nenhuma permissao AWS ate que exista uma dependencia
real que a justifique.

O state de identidade e separado do state do runtime para que `terraform destroy` do
laboratorio nao remova as credenciais necessarias para recria-lo.

## Gates de ciclo de vida

O arquivo `environments/study.tfvars` contem `provision_infrastructure` e
`destroy_infrastructure`. As variaveis sao avaliadas pela pipeline somente depois de
`validate` e `plan`:

```text
false -> nao executa apply; nenhum recurso cobravel e criado
true  -> executa apply automatico do runtime
```

Com `destroy_infrastructure=true`, o workflow encadeado `Destroy runtime` cria e aplica
um plano `terraform plan -destroy` para o state `fargateflow/study`. O escopo
`infra/identity`, o bucket compartilhado e o provedor OIDC ficam preservados. As duas
chaves sao mutuamente exclusivas.

Elas nao sao usadas em `count` ou `for_each`. Por isso, alterar para `false` nao pede
a destruicao dos recursos existentes; apenas bloqueia a respectiva operacao automatica.

## State remoto compartilhado

```text
Bucket: terraform-states-761018861028-us-east-1
Runtime key:  fargateflow/study/terraform.tfstate
Identity key: fargateflow/identity/terraform.tfstate
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
