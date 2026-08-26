data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "game_alb" {
  name        = "${var.project_name}-game-alb"
  description = "Allows public HTTP traffic to the game load balancer."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "game_alb_http" {
  security_group_id = aws_security_group.game_alb.id
  description       = "HTTP from the internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "game_alb_to_task" {
  security_group_id            = aws_security_group.game_alb.id
  description                  = "HTTP to game tasks"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.game_task.id
}

resource "aws_security_group" "game_task" {
  name        = "${var.project_name}-game-task"
  description = "Allows game tasks to receive traffic only from the game load balancer."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "game_task_from_alb" {
  security_group_id            = aws_security_group.game_task.id
  description                  = "HTTP from game load balancer"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.game_alb.id
}

resource "aws_vpc_security_group_egress_rule" "game_task_all" {
  security_group_id = aws_security_group.game_task.id
  description       = "Outbound application and AWS service traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "menu_alb" {
  name        = "${var.project_name}-menu-alb"
  description = "Allows CloudFront to reach the internal menu load balancer."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "menu_alb_from_cloudfront" {
  security_group_id = aws_security_group.menu_alb.id
  description       = "HTTP from CloudFront VPC origins"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
}

resource "aws_vpc_security_group_egress_rule" "menu_alb_to_task" {
  security_group_id            = aws_security_group.menu_alb.id
  description                  = "HTTP to menu tasks"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.menu_task.id
}

resource "aws_security_group" "menu_task" {
  name        = "${var.project_name}-menu-task"
  description = "Allows menu tasks to receive traffic only from the menu load balancer."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "menu_task_from_alb" {
  security_group_id            = aws_security_group.menu_task.id
  description                  = "HTTP from menu load balancer"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.menu_alb.id
}

resource "aws_vpc_security_group_egress_rule" "menu_task_all" {
  security_group_id = aws_security_group.menu_task.id
  description       = "Outbound application and AWS service traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "interface_endpoint" {
  name        = "${var.project_name}-interface-endpoint"
  description = "Allows ECS tasks to connect to interface VPC endpoints over HTTPS."
  vpc_id      = var.vpc_id
}

resource "aws_security_group" "cache" {
  name        = "${var.project_name}-cache"
  description = "Allows Redis traffic from ECS tasks."
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_game_task" {
  security_group_id            = aws_security_group.cache.id
  description                  = "Redis from game tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.game_task.id
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_menu_task" {
  security_group_id            = aws_security_group.cache.id
  description                  = "Redis from menu tasks"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.menu_task.id
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoint_from_game_task" {
  security_group_id            = aws_security_group.interface_endpoint.id
  description                  = "HTTPS from game tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.game_task.id
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoint_from_menu_task" {
  security_group_id            = aws_security_group.interface_endpoint.id
  description                  = "HTTPS from menu tasks"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.menu_task.id
}
