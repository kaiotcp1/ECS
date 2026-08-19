# Esta chave controla somente o job de apply da pipeline.
# false: valida e gera plan, sem criar recursos cobraveis.
# true: libera o apply automatico depois do plan bem-sucedido.
provision_infrastructure = false

# Esta chave controla somente o workflow de destroy da pipeline.
# false: preserva a infraestrutura atual.
# true: destroi os recursos gerenciados pelo state fargateflow/study.
destroy_infrastructure = false
