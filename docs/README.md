# Documentacao do FargateFlow

Esta documentacao acompanha o caminho completo de uma alteracao: do codigo Fastify
ate uma tarefa ARM64 no ECS Fargate, incluindo rede, seguranca, observabilidade,
Terraform e GitHub Actions.

## Navegacao por escopo

| Escopo                                        | Conteudo                                                          |
| --------------------------------------------- | ----------------------------------------------------------------- |
| [Arquitetura cloud](architecture.md)          | Visao geral, diagramas, fluxo de trafego e decisoes arquiteturais |
| [Aplicacao e container](application.md)       | API, configuracao, logs, testes, encerramento e imagem Docker     |
| [Infraestrutura Terraform](infrastructure.md) | Recursos AWS, rede, state remoto e limites de ownership           |
| [CI/CD](ci-cd.md)                             | Pipelines de validacao, plan, build, scan e deploy no ECS         |
| [Operacao e seguranca](operations.md)         | Provisionamento, verificacao, troubleshooting, custos e destroy   |

## Leitura sugerida

1. Comece pela [arquitetura cloud](architecture.md) para entender os componentes.
2. Veja [infraestrutura Terraform](infrastructure.md) para conhecer como eles sao criados.
3. Leia [CI/CD](ci-cd.md) para acompanhar uma entrega de ponta a ponta.
4. Use [operacao e seguranca](operations.md) como runbook do laboratorio.

> O projeto e um laboratorio temporario. A arquitetura descrita e reproduzivel pelo
> Terraform, mas os recursos de runtime podem estar destruidos para evitar custos.
