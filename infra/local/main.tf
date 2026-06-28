resource "null_resource" "cluster_placeholder" {
  triggers = {
    cluster_name = var.cluster_name
  }
}
