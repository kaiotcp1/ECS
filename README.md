# AWS Fargate Infrastructure Lab (FargateFlow)

API minima em Node.js, TypeScript e Fastify usada para estudar uma implantacao real
em Amazon ECS com AWS Fargate. A infraestrutura da aplicacao e declarada em Terraform;
o GitHub Actions valida o codigo, publica uma imagem ARM64 imutavel no ECR e atualiza o
servico ECS.

## Arquitetura

- Application Load Balancer publico em duas subnets publicas.
- Duas tarefas Fargate ARM64 em subnets privadas.
- NAT Gateway regional em modo automatico para saida das tarefas.
- ECR privado com tags imutaveis e scan basico no push.
- CloudWatch Logs com retencao de tres dias.
- GitHub Actions autenticado na AWS por OIDC, sem access keys permanentes.
- State remoto no S3 com versionamento e lockfile nativo.

O bucket de state e o provedor OIDC sao compartilhados pela conta. Eles nao pertencem
ao state do FargateFlow e, portanto, nao sao removidos por `terraform destroy`.

## Desenvolvimento local

Requisitos: Node.js 24 e npm.

```powershell
npm ci
npm run dev
```

Validacao completa:

```powershell
npm run format:check
npm run lint
npm test
npm run build
```

Endpoints:

```text
GET /
GET /health
```

## Backend Terraform compartilhado

O bucket abaixo foi criado uma unica vez pela AWS CLI e pode armazenar states de
outros projetos. Cada projeto deve usar uma chave diferente no bloco `backend "s3"`.

```text
Bucket: kaiotcp1-terraform-state-761018861028-us-east-1
FargateFlow: fargateflow/study/terraform.tfstate
Outro projeto: nome-do-projeto/ambiente/terraform.tfstate
```

Criacao reproduzivel em `us-east-1`:

```powershell
$bucket = "kaiotcp1-terraform-state-761018861028-us-east-1"

aws s3api create-bucket --bucket $bucket --region us-east-1
aws s3api put-public-access-block --bucket $bucket --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration Status=Enabled
aws s3api put-bucket-tagging --bucket $bucket --tagging "TagSet=[{Key=Name,Value=kaiotcp1-terraform-state},{Key=Purpose,Value=terraform-state},{Key=ManagedBy,Value=cli},{Key=Owner,Value=kaio}]"
aws s3api put-bucket-policy --bucket $bucket --policy file://docs/terraform-state-bucket-policy.json
```

O S3 aplica criptografia SSE-S3 automaticamente a novos objetos. A configuracao foi
tambem fixada explicitamente como AES-256. Nao usamos uma chave KMS propria para evitar
o custo mensal da chave. O arquivo de policy exige transporte HTTPS.

Validacao do backend:

```powershell
aws s3api get-public-access-block --bucket $bucket
aws s3api get-bucket-versioning --bucket $bucket
aws s3api get-bucket-encryption --bucket $bucket
aws s3api get-bucket-policy-status --bucket $bucket
```

## Terraform

Requisitos: Terraform 1.15, AWS CLI autenticada na conta correta e Docker para o CD.

```powershell
cd infra
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
```

O primeiro `apply` cria o servico ECS com zero tarefas, pois o ECR ainda pode estar
vazio. Depois disso, o workflow `CD`:

1. constroi e publica a imagem ARM64;
2. bloqueia o deploy se o scan encontrar vulnerabilidades HIGH ou CRITICAL;
3. registra uma task definition apontando para o digest imutavel;
4. escala o servico para duas tarefas;
5. aguarda estabilidade e testa `GET /health` pelo ALB.

Alteracoes de `desired_count` e `task_definition` feitas pelo CD sao ignoradas pelo
Terraform para evitar disputa de ownership entre as duas ferramentas.

## Custos e remocao

NAT Gateway, enderecos IPv4 publicos, Application Load Balancer e tarefas Fargate
geram cobranca enquanto existem. Ao terminar o laboratorio:

```powershell
cd infra
terraform plan -destroy
terraform destroy
```

Confirme que nao sobraram recursos do projeto:

```powershell
aws ec2 describe-nat-gateways --filter Name=tag:Project,Values=aws-fargate-infrastructure-lab Name=state,Values=pending,available,deleting
aws ec2 describe-addresses --filters Name=tag:Project,Values=aws-fargate-infrastructure-lab
aws elbv2 describe-load-balancers --query "LoadBalancers[?starts_with(LoadBalancerName, 'fargateflow')]"
aws ecs describe-services --cluster fargateflow-cluster --services fargateflow-service
aws ecr describe-repositories --repository-names fargateflow
```

O state S3, o provedor GitHub OIDC e a role compartilhada do GitHub Actions permanecem
para os proximos projetos. Um bucket vazio nao tem custo de armazenamento; os pequenos
arquivos de state armazenados geram apenas custo proporcional de S3.

## Permissoes do plan no GitHub Actions

A role compartilhada usa `PowerUserAccess`, que exclui operacoes de IAM. O refresh do
Terraform precisa ler as roles referenciadas pela stack, mesmo sem altera-las. A policy
inline `TerraformReadIAM` libera somente consultas `iam:Get*` e `iam:List*`:

```powershell
aws iam put-role-policy --role-name github-actions-deploy-role --policy-name TerraformReadIAM --policy-document file://docs/github-actions-terraform-read-policy.json
```

Essa policy nao permite criar, alterar ou excluir identidades. A permissao separada
`iam:PassRole` continua limitada as roles de runtime previamente aprovadas.
