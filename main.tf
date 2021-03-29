data "aws_caller_identity" "current" {
}

data "aws_elb_service_account" "default" {
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ELASTIC FILE SYSTEM (NFS) TO PROVIDE PERMANENT STORAGE FOR GRAFANA 
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_efs_file_system" "ecs_service_storage" {
  encrypted = true

  tags = {
    Name = "${var.service_name}-efs"
  }
}

resource "aws_efs_mount_target" "ecs_service_storage" {
  count           = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.ecs_service_storage.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [aws_security_group.efs_sg.id]
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE CLOUDWATCH LOG GROUP FOR THIS SERVICE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "ecs_service" {
  name              = var.cloudwatch_log_group_name
  retention_in_days = 30
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS TASK TO RUN THE DOCKER CONTAINER
# ---------------------------------------------------------------------------------------------------------------------

# This template_file defines the Docker containers we want to run in our ECS Task
data "template_file" "ecs_task_container_definitions" {
  template = file("${path.module}/templates/container-definition.json")

  vars = {
    aws_region = var.aws_region
    container_name = var.service_name
    service_name = var.service_name
    image = var.image
    version = var.image_version
    cloudwatch_log_group_name = var.cloudwatch_log_group_name
    cpu = var.cpu
    memory = var.memory
    user = "472:0"
    container_port = var.container_port
  }
}

resource "aws_ecs_task_definition" "service" {
    family   = var.service_name
    container_definitions = data.template_file.ecs_task_container_definitions.rendered
    network_mode              = "awsvpc"
    cpu                       = var.cpu
    memory                    = var.memory
    requires_compatibilities  = ["FARGATE", "EC2"]
    task_role_arn             = aws_iam_role.ecs_task_role.arn
    execution_role_arn        = aws_iam_role.ecs_task_execution_role.arn

    volume {
        name = "grafana-db"

        efs_volume_configuration {
            file_system_id = aws_efs_file_system.ecs_service_storage.id
            root_directory = "/grafana"
        }
    }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ECS SERVICE TO RUN THE ECS TASK
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_ecs_cluster" "main" {
  count = var.create_ecs_cluster == true ? 1 : 0
  name = var.ecs_cluster
}

# Create the ECS service
resource "aws_ecs_service" "ecs_service" {
  name                                = var.service_name
  cluster                             = var.ecs_cluster
  task_definition                     = aws_ecs_task_definition.service.arn
  desired_count                       = var.desired_number_of_tasks
  deployment_maximum_percent          = var.deployment_maximum_percent
  deployment_minimum_healthy_percent  = var.deployment_minimum_healthy_percent
  health_check_grace_period_seconds   = var.health_check_grace_period_seconds
  launch_type                         = "FARGATE"
  platform_version                    = var.platform_version
  depends_on                          = [aws_lb_target_group.target_group]

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  network_configuration {
    subnets             = var.private_subnet_ids
    security_groups     = [aws_security_group.ecs_service_security_group.id]
    assign_public_ip    = true
  }
}