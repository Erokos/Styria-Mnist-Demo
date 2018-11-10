# Set up the name zone region
resource "aws_route53_zone" "primary" {
  name = "my-example.com"
}

# Link to the Load Balancer
resource "aws_route53_record" "www" {
  zone_id = "${aws_route53_zone.primary.zone_id}"
  name    = "www.my-styria-example.com"
  type    = "CNAME"
  ttl     = "300"
  records = ["${module.elb.this_elb_name}"]
}
