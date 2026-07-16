# Tag the default VPC subnets so the in-cluster AWS cloud controller can place
# a public LoadBalancer (the order-service Service, type: LoadBalancer) in them.
# Without the kubernetes.io/role/elb tag the ELB never gets an address and the
# smoke test would hang. Destroying removes the tags again.
resource "aws_ec2_tag" "elb_role" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}
