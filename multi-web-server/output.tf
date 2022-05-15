output "ws_elb_dns_name" {
  value       = aws_lb.ws-elb.dns_name
  description = "Domain name of the load balancer to access instances home page"
}