# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE APPLICATION LOAD BALANCER FOR THE ECS SERVICE
# ---------------------------------------------------------------------------------------------------------------------
# Define a S3 bucket for the ALB logs
resource "aws_s3_bucket" "alb_logs_s3_bucket" {
  bucket = "${var.service_name}-alb-logs"
  acl    = "log-delivery-write"
  versioning {
    enabled = true
  }
}

data "aws_iam_policy_document" "default" {
  statement {
    sid = ""

    principals {
      type        = "AWS"
      identifiers = [join("", data.aws_elb_service_account.default.*.arn)]
    }

    effect = "Allow"

    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::${aws_s3_bucket.alb_logs_s3_bucket.id}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "b" {
  bucket = aws_s3_bucket.alb_logs_s3_bucket.id
  policy = join("", data.aws_iam_policy_document.default.*.json)
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE LB TARGET GROUP TO WHICH THE SERVICE ABOVE WILL ATTACH
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb_target_group" "target_group" {
  name                  = var.service_name
  port                  = var.container_port
  protocol              = var.alb_target_group_protocol
  target_type           = "ip"
  vpc_id                = var.vpc_id
  deregistration_delay  = var.alb_target_group_deregistration_delay

  health_check {
    enabled             = true
    interval            = var.health_check_interval
    path                = var.health_check_path
    port                = var.container_port
    protocol            = var.health_check_protocol
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = var.health_check_matcher
  }
}

# Create the actual ALB
resource "aws_lb" "ecs_alb" {
  name                              = "${var.service_name}-alb"
  internal                          = false
  load_balancer_type                = "application"
  security_groups                   = ["${aws_security_group.alb_sg.id}"]
  subnets                           = var.public_subnet_ids
  enable_cross_zone_load_balancing  = true
  enable_http2                      = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs_s3_bucket.bucket
    enabled = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE HTTP(S) LISTENERS
# These will accept the HTTP(S) requests and forward them to the proper target groups
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}