terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Construir el ARN del rol para cada cuenta
  role_arns = {
    for k, v in var.aws_accounts : k => "arn:aws:iam::${v.account_id}:role${var.iam_role_path}${var.iam_role_name}"
  }

  # Tags comunes para recursos AWS
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "terraform"
      Purpose     = "grafana-cloudwatch-integration"
    },
    var.tags
  )
}

#######################################
# IAM Role y Policy para CloudWatch
#######################################

# IAM Policy Document - Permisos de CloudWatch
data "aws_iam_policy_document" "cloudwatch_policy" {
  count = var.create_iam_role ? 1 : 0

  # CloudWatch Metrics - Lectura
  statement {
    sid = "CloudWatchMetricsReadAccess"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport"
    ]
    resources = ["*"]
  }

  # CloudWatch Logs - Lectura
  statement {
    sid = "CloudWatchLogsReadAccess"
    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
      "logs:FilterLogEvents"
    ]
    resources = ["*"]
  }

  # EC2 - Describir regiones (necesario para el selector de región)
  statement {
    sid = "EC2DescribeRegions"
    actions = [
      "ec2:DescribeRegions"
    ]
    resources = ["*"]
  }

  # Resource Groups Tagging - Para filtrar por tags
  statement {
    sid = "TagsReadAccess"
    actions = [
      "tag:GetResources"
    ]
    resources = ["*"]
  }

  # Statements adicionales configurables
  dynamic "statement" {
    for_each = var.additional_iam_policy_statements
    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

# IAM Policy Document - Trust Policy para Assume Role
data "aws_iam_policy_document" "assume_role_policy" {
  count = var.create_iam_role ? 1 : 0

  statement {
    sid     = "GrafanaCloudAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = var.grafana_cloud_role_name != "" ? [
        "arn:aws:iam::${var.grafana_cloud_account_id}:role/${var.grafana_cloud_role_name}"
        ] : [
        "arn:aws:iam::${var.grafana_cloud_account_id}:root"
      ]
    }

    # External ID para seguridad adicional (muy recomendado)
    dynamic "condition" {
      for_each = var.external_id != "" ? [1] : []
      content {
        test     = "StringEquals"
        variable = "sts:ExternalId"
        values   = [var.external_id]
      }
    }
  }
}

# IAM Role
resource "aws_iam_role" "grafana_cloudwatch" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_name
  path               = var.iam_role_path
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy[0].json

  tags = merge(local.common_tags, {
    Name = var.iam_role_name
  })
}

# IAM Policy
resource "aws_iam_policy" "cloudwatch_read" {
  count = var.create_iam_role ? 1 : 0

  name        = "${var.iam_role_name}-policy"
  path        = var.iam_role_path
  description = "Policy para permitir a Grafana leer métricas y logs de CloudWatch"
  policy      = data.aws_iam_policy_document.cloudwatch_policy[0].json

  tags = local.common_tags
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "grafana_cloudwatch" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.grafana_cloudwatch[0].name
  policy_arn = aws_iam_policy.cloudwatch_read[0].arn
}

#######################################
# Grafana CloudWatch Data Sources
#######################################

# CloudWatch Data Sources para múltiples cuentas AWS
# Documentación: https://grafana.com/docs/grafana-cloud/connect-externally-hosted/data-sources/aws-cloudwatch/
resource "grafana_data_source" "cloudwatch" {
  for_each = var.aws_accounts

  type = "cloudwatch"
  name = each.value.name
  uid  = "cloudwatch-${each.key}"

  # Configuración básica del data source
  is_default = each.value.is_default

  json_data_encoded = jsonencode({
    # Tipo de autenticación
    authType = each.value.auth_type

    # Configuración de Assume Role para acceso cross-account
    assumeRoleArn = local.role_arns[each.key]
    externalId    = var.external_id != "" ? var.external_id : null

    # Región por defecto
    defaultRegion = each.value.default_region

    # Namespaces personalizados para métricas custom
    customMetricsNamespaces = each.value.custom_metrics_namespaces != "" ? each.value.custom_metrics_namespaces : null
  })

  # Configuración de credenciales (solo si auth_type = "keys")
  # Las credenciales se pasan de forma segura
  secure_json_data_encoded = each.value.auth_type == "keys" ? jsonencode({
    accessKey = each.value.access_key
    secretKey = each.value.secret_key
  }) : null

  # Depende del rol si se está creando
  depends_on = [aws_iam_role_policy_attachment.grafana_cloudwatch]
}
