resource "aws_ssm_parameter" "foo" {
  name  = "/grafana/GF_INSTALL_PLUGINS"
  type  = "String"
  value = "bar"
}