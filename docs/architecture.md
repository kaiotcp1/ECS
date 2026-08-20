# Arquitetura cloud

O FargateFlow demonstra uma API pequena operando em uma arquitetura AWS proxima de
um workload real: entrada publica controlada por um Application Load Balancer,
containers sem IP publico em duas zonas de disponibilidade e entrega automatizada
com credenciais temporarias.

## Visao geral

```mermaid
flowchart LR
  user([Cliente HTTP])

  subgraph aws[AWS - us-east-1]
    direction LR

    subgraph vpc[VPC 10.0.0.0/16]
      direction LR

      igw[Internet Gateway]

      subgraph public[Subnets publicas - 2 AZs]
        alb[Application Load Balancer<br/>HTTP :80]
      end

      nat[NAT Gateway regional]
      tg[Target Group IP<br/>HTTP :3000<br/>health: /health]

      subgraph private[Subnets privadas - 2 AZs]
        taskA[ECS Fargate ARM64<br/>Task A - :3000]
        taskB[ECS Fargate ARM64<br/>Task B - :3000]
      end
    end

    ecr[(Amazon ECR<br/>imagens imutaveis)]
    logs[(CloudWatch Logs<br/>retencao: 3 dias)]
    metrics[(CloudWatch<br/>dashboard + alarmes)]
    scaling[Application Auto Scaling<br/>CPU/Memoria 80%]
  end

  user -->|HTTP :80| igw --> alb
  alb --> tg
  tg --> taskA
  tg --> taskB
  taskA -. saida privada .-> nat
  taskB -. saida privada .-> nat
  nat --> igw
  ecr -. pull da imagem .-> taskA
  ecr -. pull da imagem .-> taskB
  taskA -->|logs estruturados| logs
  taskB -->|logs estruturados| logs
  alb -->|metricas de saude e 5XX| metrics
  taskA -->|CPU e memoria| metrics
  taskB -->|CPU e memoria| metrics
  metrics -->|metricas ECS| scaling
  scaling -. ajusta capacidade .-> taskA
  scaling -. ajusta capacidade .-> taskB
```

O ALB e o unico ponto de entrada publico. As tarefas recebem interfaces de rede nas
subnets privadas, nao recebem IP publico e aceitam a porta `3000` somente quando a
origem e o security group do ALB.

## Plano de entrega e controle

```mermaid
flowchart TB
  developer[Desenvolvedor] -->|push / pull request| github[GitHub]

  subgraph actions[GitHub Actions]
    ci[CI<br/>format + lint + test + build]
    tf[Terraform<br/>validate + plan + apply condicional]
    destroy[Destroy runtime<br/>destroy condicional]
    cd[CD<br/>build ARM64 + scan + deploy + smoke test]
  end

  github --> ci
  ci -->|sucesso na main| tf
  tf --> destroy
  tf --> cd

  tf -->|OIDC / STS| sharedRole[github-actions-deploy-role]
  destroy -->|OIDC / STS| sharedRole
  cd -->|OIDC / STS| sharedRole
  tf --> state[(S3 Terraform states<br/>state + lockfile)]
  sharedRole --> ecr[Amazon ECR]
  sharedRole --> ecs[Amazon ECS]
  sharedRole --> aws[AWS APIs]
  cd -->|GET /health| alb[ALB publico]
```

Nao existem access keys permanentes no GitHub. Cada execucao troca o token OIDC do
GitHub por credenciais AWS temporarias via `sts:AssumeRoleWithWebIdentity`.

## Fluxo de uma requisicao

1. O cliente resolve o DNS publico do ALB e envia uma requisicao HTTP na porta `80`.
2. O listener encaminha a requisicao ao target group `fargateflow-tg`.
3. O target group seleciona uma tarefa saudavel e envia trafego para a porta `3000`.
4. O Fastify responde e registra a requisicao em JSON no stdout do container.
5. O driver `awslogs` entrega o log ao grupo `/ecs/fargateflow` no CloudWatch.

O target group chama `GET /health` a cada 30 segundos. Uma tarefa so recebe trafego
quando passa pelos health checks do container, do ECS e do load balancer.

## Limites de rede

| Origem      | Destino           | Regra                                                     |
| ----------- | ----------------- | --------------------------------------------------------- |
| Internet    | ALB               | TCP `80` permitido                                        |
| ALB         | Tarefas ECS       | TCP `3000`, limitado por referencia entre security groups |
| Internet    | Tarefas ECS       | Sem rota de entrada e sem regra permitida                 |
| Tarefas ECS | Servicos externos | Saida pelo NAT Gateway regional                           |

## Decisoes principais

- **Duas AZs:** ALB e tarefas podem operar em mais de uma zona de disponibilidade.
- **Fargate ARM64:** executa a imagem `linux/arm64` em AWS Graviton, sem administrar EC2.
- **Imagem por digest:** o ECS recebe o digest SHA-256, eliminando ambiguidade de tags.
- **Subnets privadas:** tarefas nao ficam diretamente expostas a Internet.
- **NAT regional:** simplifica a saida multi-AZ do laboratorio, mas e um recurso pago.
- **HTTP intencional:** HTTPS e dominio ficaram fora do escopo atual do laboratorio.
- **Infraestrutura efemera:** `terraform destroy` remove o runtime quando o estudo termina.
- **Gates de ciclo de vida:** flags versionadas autorizam `apply` ou `destroy`, nunca os
  dois na mesma execucao.
- **Recuperacao automatica:** o ECS interrompe e faz rollback de deployments que nao
  estabilizam ou que sustentam erros `5XX` nos targets do ALB.
- **Observabilidade proporcional:** um dashboard CloudWatch concentra saude dos targets,
  erros `5XX`, CPU e memoria sem habilitar Container Insights.
- **Escalabilidade preparada:** Application Auto Scaling monitora CPU e memoria com alvo
  de 80%, entre zero e quatro tarefas, pronto para um futuro teste de carga.
