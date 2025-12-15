#######################################
# Outputs - IAM Resources
#######################################

output "iam_role_arn" {
  description = "ARN del IAM Role creado para Grafana CloudWatch"
  value       = var.create_iam_role ? aws_iam_role.grafana_cloudwatch[0].arn : null
}

output "iam_role_name" {
  description = "Nombre del IAM Role creado"
  value       = var.create_iam_role ? aws_iam_role.grafana_cloudwatch[0].name : null
}

output "iam_policy_arn" {
  description = "ARN de la IAM Policy creada"
  value       = var.create_iam_role ? aws_iam_policy.cloudwatch_read[0].arn : null
}

#######################################
# Outputs - Grafana Data Sources
#######################################

output "datasource_ids" {
  description = "IDs de los data sources de CloudWatch creados"
  value       = { for k, v in grafana_data_source.cloudwatch : k => v.id }
}

output "datasource_uids" {
  description = "UIDs de los data sources de CloudWatch creados"
  value       = { for k, v in grafana_data_source.cloudwatch : k => v.uid }
}

output "datasource_names" {
  description = "Nombres de los data sources de CloudWatch creados"
  value       = { for k, v in grafana_data_source.cloudwatch : k => v.name }
}

output "datasource_details" {
  description = "Detalles completos de los data sources creados"
  value = {
    for k, v in grafana_data_source.cloudwatch : k => {
      id         = v.id
      uid        = v.uid
      name       = v.name
      type       = v.type
      is_default = v.is_default
      role_arn   = local.role_arns[k]
    }
  }
}

output "role_arns_by_account" {
  description = "Mapa de ARNs de roles por cuenta (para referencia)"
  value       = local.role_arns
}
