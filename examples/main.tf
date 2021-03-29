provider "aws" {
  region = "eu-west-1"
}

module "grafana" {
    source = "../"
    aws_region = "eu-west-1"
    service_name = "grid-monitoring-grafana"
    ecs_cluster = "grid-monitoring"
    create_ecs_cluster = true
    image = "grafana/grafana"
    image_version = "latest"
    container_port = 3000
    cpu = 256
    memory = 1024
    desired_number_of_tasks = 2
    cloudwatch_log_group_name = "grid-monitoring-grafana"
    vpc_id = "vpc-051d9823b204f57d8"
    private_subnet_ids = ["subnet-004a055b961975f07", "subnet-0169f3c243ee9c60d", "subnet-0a43669f2c68ce33d"]
    public_subnet_ids = ["subnet-07fa03063a459f464", "subnet-01666e6e396d8db2b", "subnet-0cc861b5e1c5c8b85"]
    platform_version = "1.4.0"
}