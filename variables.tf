variable "environment" {
  description = "Nombre del ambiente (staging/production)"
  type        = string
}

variable "create_iam_role" {
  description = "Si se debe crear el IAM Role automáticamente en AWS"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Nombre del IAM Role a crear (se usa para todas las cuentas configuradas)"
  type        = string
  default     = "GrafanaCloudWatchRole"
}

variable "iam_role_path" {
  description = "Path del IAM Role"
  type        = string
  default     = "/"
}

# Configuración de Grafana Cloud para la trust policy
variable "grafana_cloud_account_id" {
  description = "Account ID de Grafana Cloud para la trust policy (se obtiene de Grafana Cloud)"
  type        = string
  default     = "" # El usuario debe proporcionar esto
}

variable "grafana_cloud_role_name" {
  description = "Nombre del rol de Grafana Cloud que asumirá el rol (opcional, para trust policy más restrictiva)"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID para la trust policy del assume role (se obtiene de Grafana Cloud)"
  type        = string
  default     = ""
}

variable "aws_accounts" {
  description = "Mapa de cuentas AWS para configurar como data sources de CloudWatch"
  type = map(object({
    # Nombre descriptivo para el data source en Grafana
    name = string

    # ID de la cuenta AWS (requerido para construir el ARN del rol)
    account_id = string

    # Configuración de autenticación
    auth_type = optional(string, "default") # "default", "keys", "ec2_iam_role"

    # Configuración de región
    default_region = string # Región por defecto para queries

    # Configuración opcional de credenciales (solo si auth_type = "keys")
    access_key = optional(string, "")
    secret_key = optional(string, "")

    # Configuración del data source
    enabled    = optional(bool, true)  # Si el data source está habilitado
    is_default = optional(bool, false) # Si es el data source por defecto

    # Configuración avanzada
    custom_metrics_namespaces = optional(string, "") # Namespaces personalizados separados por coma

    # Labels/Tags para organización
    labels = optional(map(string), {})
  }))
  default = {}

  # Validación removida - Grafana Cloud usa valores diferentes (grafanaAssumeRole, etc.)
  # Los valores válidos dependen de si es Grafana OSS o Grafana Cloud
}

variable "additional_iam_policy_statements" {
  description = "Statements adicionales para la IAM Policy (para permisos extra como X-Ray, EC2, etc.)"
  type = list(object({
    sid       = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags adicionales para los recursos de AWS"
  type        = map(string)
  default     = {}
}
