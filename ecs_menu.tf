resource "aws_ecs_cluster" "menu" {
  name = "${var.project_name}-menu"
}

resource "aws_iam_role" "menu_task_execution" {
  name = "${var.project_name}-menu-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "menu_task_execution" {
  role       = aws_iam_role.menu_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "menu" {
  name              = "/ecs/${var.project_name}/menu"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "menu" {
  family                   = "${var.project_name}-menu"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.menu_cpu
  memory                   = var.menu_memory
  execution_role_arn       = aws_iam_role.menu_task_execution.arn

  container_definitions = jsonencode([{
    name      = "menu"
    image     = var.menu_image
    cpu       = var.menu_cpu
    memory    = var.menu_memory
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    environment = [
      for name, value in merge(
        var.menu_environment,
        { 
          GAME_API_URL = "http://${aws_lb.game.dns_name}" 
          VALKEY_HOST = aws_elasticache_cluster.game_cache.cache_nodes[0].address
        },
        ) : {
        name  = name
        value = value
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.menu.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_lb" "menu" {
  name               = "${var.project_name}-menu"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.menu_alb.id]
  subnets            = values(aws_subnet.public)[*].id
}

resource "aws_lb_target_group" "menu" {
  name        = "${var.project_name}-menu"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/api/health"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "menu_http" {
  load_balancer_arn = aws_lb.menu.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.menu.arn
  }
}

resource "aws_ecs_service" "menu" {
  name                              = "${var.project_name}-menu"
  cluster                           = aws_ecs_cluster.menu.id
  task_definition                   = aws_ecs_task_definition.menu.arn
  desired_count                     = var.menu_desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = values(aws_subnet.public)[*].id
    security_groups  = [aws_security_group.menu_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.menu.arn
    container_name   = "menu"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.menu_http,
  ]
}

resource "aws_cloudfront_vpc_origin" "menu" {
  vpc_origin_endpoint_config {
    arn                    = aws_lb.menu.arn
    name                   = "${var.project_name}-menu"
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

output "menu_alb_dns_name" {
  value = aws_lb.menu.dns_name
}
