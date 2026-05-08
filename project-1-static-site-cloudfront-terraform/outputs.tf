output "cloudfront_url" {
  value = aws_cloudfront_distribution.static_site_cdn.domain_name
}

output "s3_bucket_name" {
  value = aws_s3_bucket.static_site.bucket
}
