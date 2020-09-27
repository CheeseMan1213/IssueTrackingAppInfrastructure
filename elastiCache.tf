resource "aws_elasticache_cluster" "eb_alb_redis_cache" {
  cluster_id           = "eb-alb-redis-cache"
  engine               = "redis"
  node_type            = "cache.t2.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"
  port                 = 6379
  subnet_group_name    = "issue-tracking-subnet-group"
  security_group_ids   = ["sg-081c1d2cdad13f62c"]

  apply_immediately = true
}
