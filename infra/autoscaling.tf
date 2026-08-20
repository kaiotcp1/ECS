resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = local.autoscaling.max_capacity
  min_capacity       = local.autoscaling.min_capacity
  resource_id        = "service/${aws_ecs_cluster.app.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu" {
  name               = local.names.cpu_scaling_policy
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = local.autoscaling.target_utilization
    scale_in_cooldown  = local.autoscaling.cooldown_seconds
    scale_out_cooldown = local.autoscaling.cooldown_seconds
    disable_scale_in   = true

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory" {
  name               = local.names.memory_scaling_policy
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = local.autoscaling.target_utilization
    scale_in_cooldown  = local.autoscaling.cooldown_seconds
    scale_out_cooldown = local.autoscaling.cooldown_seconds
    disable_scale_in   = true

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}
