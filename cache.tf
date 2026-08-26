resource "aws_elasticache_cluster" "game_cache" {
  cluster_id           = "game-cache"
  engine               = "redis"
  node_type            = "cache.t4g.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.cache_subnets.name
  security_group_ids   = [aws_security_group.cache.id]
}

resource "aws_elasticache_subnet_group" "cache_subnets" {
  name       = "${var.project_name}-cache-subnets"
  subnet_ids = values(aws_subnet.cache)[*].id
}