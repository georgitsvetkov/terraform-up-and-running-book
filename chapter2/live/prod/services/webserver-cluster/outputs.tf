output "alb_dns_name" {
      value       = module.example.dns_name
      description = "The domain name of the load balancer"
}