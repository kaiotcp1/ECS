locals {
  # Controlam somente os workflows; nunca condicionam recursos Terraform.
  provision_infrastructure = true
  destroy_infrastructure   = false

  names = {
    vpc                  = "${var.name_prefix}-vpc"
    main_route_table     = "${var.name_prefix}-main-rt"
    internet_gateway     = "${var.name_prefix}-igw"
    nat_gateway          = "${var.name_prefix}-nat-regional"
    public_route_table   = "${var.name_prefix}-public-rt"
    alb_security_group   = "${var.name_prefix}-alb-sg"
    tasks_security_group = "${var.name_prefix}-ecs-tasks-sg"
    load_balancer        = "${var.name_prefix}-alb"
    target_group         = "${var.name_prefix}-tg"
    log_group            = "/ecs/${var.name_prefix}"
    cluster              = "${var.name_prefix}-cluster"
    service              = "${var.name_prefix}-service"
    container            = "${var.name_prefix}-api"
    task_role            = "${var.name_prefix}-ecs-task-role"
    task_execution_role  = "${var.name_prefix}-ecs-task-execution-role"
  }
}
