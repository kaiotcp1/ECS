# Operacao e seguranca

Este runbook cobre o ciclo esperado do laboratorio: criar, publicar, validar e remover.

## Pre-requisitos compartilhados

Antes do primeiro provisionamento, a conta precisa ter:

- bucket `terraform-states-761018861028-us-east-1`;
- provedor IAM OIDC do GitHub;
- role compartilhada `github-actions-deploy-role` com permissoes de Terraform e deploy;
- AWS CLI autenticada na conta e regiao corretas para operacao local.

Esses recursos sao reutilizados por outros projetos e nao pertencem ao state do
FargateFlow.

A role compartilhada tambem precisa da policy
`docs/github-actions-fargateflow-runtime-iam-policy.json`, que permite ao Terraform
gerenciar apenas as roles de runtime do ECS do FargateFlow.

## Criar a infraestrutura

```powershell
cd infra
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

O apply cria o service com zero tarefas. Em seguida, execute o workflow `CD` na branch
`main`; ele publica a primeira imagem e escala o service para duas tarefas.

Para permitir criacao automatica pela pipeline, altere temporariamente:

```hcl
# infra/locals.tf
provision_infrastructure = true
```

Envie a alteracao para `main`. Depois do provisionamento e da validacao do endpoint,
retorne o valor para `false` antes de novos pushes. Com `false`, a pipeline ainda
executa CI, identidade e plan, mas nao cria recursos cobraveis.

Para solicitar a destruicao automatica pelo workflow de governanca, use:

```hcl
provision_infrastructure = false
destroy_infrastructure = true
```

Depois da conclusao, retorne `destroy_infrastructure` para `false`. Nunca mantenha as
duas chaves em `true`; a pipeline falha antes de alterar recursos.

## Validar

```powershell
$healthUrl = terraform -chdir=infra output -raw health_url
Invoke-RestMethod $healthUrl
```

Resposta esperada:

```json
{
  "status": "ok"
}
```

Verificacoes adicionais:

```powershell
aws ecs describe-services --cluster fargateflow-cluster --services fargateflow-service
aws ecr describe-images --repository-name fargateflow
aws logs tail /ecs/fargateflow --since 10m
```

## Controles de seguranca

- tarefas privadas sem IPv4 publico;
- entrada nas tarefas permitida apenas pelo security group do ALB;
- container executado como usuario sem privilegios e filesystem raiz somente leitura;
- roles separadas para a aplicacao e para a inicializacao da task;
- trust policy das tasks limitada por conta e ARN de origem ECS;
- imagens ECR imutaveis, criptografadas e analisadas no push;
- deploy bloqueado para vulnerabilidades HIGH ou CRITICAL;
- IaC validada por `tflint` e Trivy, com excecoes de risco justificadas e versionadas;
- state S3 privado, versionado, criptografado e acessivel somente via TLS;
- GitHub Actions sem access keys permanentes.

## Observabilidade e recuperacao

Logs estruturados ficam em `/ecs/fargateflow` por tres dias. O dashboard
`fargateflow-observability` consolida CPU, memoria, saude dos targets e erros `5XX`.
O deployment circuit breaker do ECS faz rollback quando uma nova revisao nao estabiliza;
o alarme `fargateflow-target-5xx` tambem aciona rollback quando a nova revisao sustenta
cinco ou mais erros `5XX` por tres minutos. Health checks em camadas detectam falhas
dentro do container e removem targets indisponiveis do ALB.

Para investigar um deploy:

1. consulte o summary do workflow CD;
2. verifique eventos do service ECS;
3. confirme a saude dos targets no target group;
4. consulte os streams mais recentes no CloudWatch Logs;
5. confira os findings do scan da imagem no ECR.

Para abrir o dashboard pelo Terraform:

```powershell
terraform -chdir=infra output -raw observability_dashboard_url
```

## Custos

Os principais recursos cobrados durante o laboratorio sao NAT Gateway, IPv4 publico,
Application Load Balancer e tarefas Fargate. ECR, CloudWatch e S3 tambem podem gerar
custos proporcionais a armazenamento, requests e transferencia. Os tres alarmes
CloudWatch adicionam um pequeno custo mensal enquanto a stack existir; o destroy os
remove junto com o runtime. O autoscaling pode elevar o service de duas para ate quatro
tarefas se houver CPU ou memoria suficiente para atingir o alvo de 80%.

O NAT regional automatico pode criar enderecos conforme as AZs usadas. Por isso, a
stack nao deve permanecer ativa sem necessidade.

## Destruir com seguranca

```powershell
cd infra
terraform plan -destroy
terraform destroy
```

Depois, confirme que os recursos cobraveis do projeto desapareceram:

```powershell
aws ec2 describe-nat-gateways --filter Name=tag:Project,Values=aws-fargate-infrastructure-lab Name=state,Values=pending,available,deleting
aws ec2 describe-addresses --filters Name=tag:Project,Values=aws-fargate-infrastructure-lab
aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, 'fargateflow')]"
aws ecs describe-services --cluster fargateflow-cluster --services fargateflow-service
aws ecr describe-repositories --repository-names fargateflow
```

O bucket compartilhado de states, o provedor OIDC e as roles de identidade do
FargateFlow devem permanecer. O state vazio do runtime preserva o historico sem manter
a infraestrutura ativa.
