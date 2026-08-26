resource "aws_ecs_cluster" "game" {
  name = "${var.project_name}-game"
}

resource "aws_iam_role" "game_task_execution" {
  name = "${var.project_name}-game-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "game_task_execution" {
  role       = aws_iam_role.game_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "game_task" {
  name = "${var.project_name}-game-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "game_openai_secret_read" {
  name = "${var.project_name}-game-openai-secret-read"
  role = aws_iam_role.game_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.openai_api_key_secret_arn
    }]
  })
}

# ECS obtains task-definition secrets using the execution role.
resource "aws_iam_role_policy" "game_execution_secret_read" {
  name = "${var.project_name}-game-execution-secret-read"
  role = aws_iam_role.game_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.openai_api_key_secret_arn
    }]
  })
}

resource "aws_cloudwatch_log_group" "game" {
  name              = "/ecs/${var.project_name}/game"
  retention_in_days = 14
}

resource "aws_ecs_task_definition" "game" {
  family                   = "${var.project_name}-game"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.game_cpu
  memory                   = var.game_memory
  execution_role_arn       = aws_iam_role.game_task_execution.arn
  task_role_arn            = aws_iam_role.game_task.arn

  container_definitions = jsonencode([{
    name      = "game"
    image     = var.game_image
    cpu       = var.game_cpu
    memory    = var.game_memory
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    secrets = [{
      name      = "OPENAI_API_KEY"
      valueFrom = var.openai_api_key_secret_arn
    }]
    environment = [
      for name, value in merge(
        var.game_environment,
        {
          REDIS_HOST = aws_elasticache_cluster.game_cache.cache_nodes[0].address
        }
      ) : {
        name = name
        value = value
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.game.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_lb" "game" {
  name               = "${var.project_name}-game"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.game_alb.id]
  subnets            = values(aws_subnet.public)[*].id
}

resource "aws_lb_target_group" "game" {
  name        = "${var.project_name}-game"
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

resource "aws_lb_listener" "game_http" {
  load_balancer_arn = aws_lb.game.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game.arn
  }
}

resource "aws_ecs_service" "game" {
  name                              = "${var.project_name}-game"
  cluster                           = aws_ecs_cluster.game.id
  task_definition                   = aws_ecs_task_definition.game.arn
  desired_count                     = var.game_desired_count
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = values(aws_subnet.public)[*].id
    security_groups  = [aws_security_group.game_task.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.game.arn
    container_name   = "game"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.game_http,
  ]
}

output "game_alb_dns_name" {
  value = aws_lb.game.dns_name
}

# VPC Endpoint required to communicate with AWS Secrets Manager
resource "aws_vpc_endpoint" "secrets_link" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.ap-southeast-2.secretsmanager"
  vpc_endpoint_type = "Interface"

  subnet_ids = values(aws_subnet.public)[*].id

  security_group_ids = [aws_security_group.interface_endpoint.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_link" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.ap-southeast-2.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids = values(aws_subnet.public)[*].id

  security_group_ids = [aws_security_group.interface_endpoint.id]

  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.ap-southeast-2.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = values(aws_subnet.public)[*].id
  security_group_ids  = [aws_security_group.interface_endpoint.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.ap-southeast-2.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids          = values(aws_subnet.public)[*].id
  security_group_ids  = [aws_security_group.interface_endpoint.id]
  private_dns_enabled = true
}
