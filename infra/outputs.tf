output "alb_dns_name" {
  description = "DNS publico do Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "health_url" {
  description = "Endpoint publico usado pelo smoke test."
  value       = "http://${aws_lb.app.dns_name}/health"
}

output "ecr_repository_url" {
  description = "Repositorio da imagem da aplicacao."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_service" {
  description = "Cluster e servico atualizados pelo workflow de CD."
  value       = "${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
}
