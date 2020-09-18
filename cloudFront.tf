/*
The CloudFront distribution needs a origin_id.
I specify it like this to make it easier to change, since it is used in more than one place.
*/
locals {
  eb_alb_origin_id = "IssueTrackingAppOrigin"
}
resource "aws_cloudfront_distribution" "eb_alb_distribution" {
  /*
    For the 'domain_name', the best way to specify this value would be to find a way to
    reference it with what I have already created in terraform. However, I did not
    create a load balancer resource directly. Throughout the entierty of this project,
    you will not find the resource 'aws_lb'. This is because I created an Elastic Beanstalk
    environment, and then told that to make the load balancer. I was unable to figure out
    how to reference the load balancer DNS from the 'aws_elastic_beanstalk_environment'
    resource. Therefore, I have hardcoded it.
  */
  origin {
    domain_name = "awseb-AWSEB-7527Y8JVIQXZ-1769747976.us-east-1.elb.amazonaws.com"
    # domain_name = aws_elastic_beanstalk_environment.issue-tracking-eb-ev.cname
    origin_id = local.eb_alb_origin_id

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "match-viewer"
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_keepalive_timeout = 60
      origin_read_timeout      = 60
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "This is the CloudFront Distribution for my IssueTrackingApp."
  default_root_object = "index.html"

  aliases = ["james2ch9developer.com", "www.james2ch9developer.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.eb_alb_origin_id

    forwarded_values {
      headers      = ["*"]
      query_string = false

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = false
    acm_certificate_arn            = "arn:aws:acm:us-east-1:475640621870:certificate/3fc22192-ba8a-4936-a1f7-b7e3811c31c8"
    minimum_protocol_version       = "TLSv1.1_2016"
    ssl_support_method             = "sni-only"
  }
}