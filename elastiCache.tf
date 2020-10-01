resource "aws_elasticache_cluster" "eb_alb_redis_cache" {
  cluster_id           = "eb-alb-redis-cache"
  engine               = "redis"
  node_type            = "cache.t2.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis5.0"
  engine_version       = "5.0.6"
  port                 = 6379
  # This subnet group was created outside of Terraform.
  subnet_group_name  = "issue-tracking-subnet-group"
  security_group_ids = ["sg-081c1d2cdad13f62c"]

  # This line is importent, becasue it makes that changes take effect immediately upon the apply.
  # Otherwise, even after the terraform apply it will wait until the next maintainance window.
  apply_immediately = true
}
