# AWS CloudWatch Collector Module

Módulo de Terraform para configurar Amazon CloudWatch como data source en Grafana Cloud, con soporte para múltiples cuentas AWS usando **Assume Role**.

## Características

- ✅ **Creación automática del IAM Role** en AWS
- ✅ Soporte para múltiples cuentas AWS
- ✅ Autenticación via Assume Role (cross-account)
- ✅ Soporte para External ID (seguridad adicional)
- ✅ Configuración de namespaces personalizados
- ✅ Permisos adicionales configurables
- ✅ Acceso a métricas y logs de CloudWatch

## Arquitectura

```
┌─────────────────────┐         ┌─────────────────────┐
│   Grafana Cloud     │         │     AWS Account     │
│                     │         │                     │
│  ┌───────────────┐  │  STS    │  ┌───────────────┐  │
│  │  CloudWatch   │──┼─────────┼──│   IAM Role    │  │
│  │  Data Source  │  │ Assume  │  │ (auto-created)│  │
│  └───────────────┘  │  Role   │  └───────┬───────┘  │
│                     │         │          │          │
└─────────────────────┘         │  ┌───────▼───────┐  │
                                │  │  CloudWatch   │  │
                                │  │  Logs/Metrics │  │
                                │  └───────────────┘  │
                                └─────────────────────┘
```

## Prerequisitos

### 1. Obtener credenciales de Grafana Cloud

Antes de ejecutar el módulo, necesitas obtener estos valores de Grafana Cloud:

1. Ve a **Connections** → **Data sources** → **Add data source** → **CloudWatch**
2. Selecciona **"Assume Role"** como Authentication Provider
3. Copia:
   - **Grafana's AWS Account ID** → `grafana_cloud_account_id`
   - **External ID** → `external_id`

![Grafana CloudWatch Config](https://grafana.com/docs/grafana/latest/datasources/cloudwatch/cloudwatch-auth-assume-role-arn.png)

## Uso

### Configuración Básica (con creación automática de IAM Role)

```hcl
inputs = {
  environment = "production"

  # Crear IAM Role automáticamente
  create_iam_role = true
  iam_role_name   = "GrafanaCloudWatchRole"

  # Credenciales de Grafana Cloud (obtener de la UI)
  grafana_cloud_account_id = "123456789012"  # Account ID de Grafana Cloud
  external_id              = "grafana-xxxxx"  # External ID de Grafana Cloud

  # Cuentas AWS a monitorear
  aws_accounts = {
    "prod" = {
      name           = "CloudWatch - Production"
      account_id     = "111111111111"  # Tu Account ID de AWS
      default_region = "us-east-1"
      enabled        = true
      is_default     = true
      labels         = { account = "production" }
    }
  }
}
```

### Múltiples Cuentas AWS

```hcl
aws_accounts = {
  "prod" = {
    name           = "CloudWatch - Production"
    account_id     = "111111111111"
    default_region = "us-east-1"
    enabled        = true
    is_default     = true
    labels         = { account = "production" }
  }

  "staging" = {
    name           = "CloudWatch - Staging"
    account_id     = "222222222222"
    default_region = "us-east-1"
    enabled        = true
    is_default     = false
    labels         = { account = "staging" }
  }

  "shared-services" = {
    name                      = "CloudWatch - Shared Services"
    account_id                = "333333333333"
    default_region            = "us-east-1"
    enabled                   = true
    is_default                = false
    custom_metrics_namespaces = "CWAgent,ContainerInsights"
    labels                    = { account = "shared-services" }
  }
}
```

### Con Permisos Adicionales

```hcl
# Agregar permisos para X-Ray, EC2, etc.
additional_iam_policy_statements = [
  {
    sid       = "XRayReadAccess"
    actions   = ["xray:GetTraceSummaries", "xray:BatchGetTraces"]
    resources = ["*"]
  },
  {
    sid       = "EC2DescribeInstances"
    actions   = ["ec2:DescribeInstances", "ec2:DescribeTags"]
    resources = ["*"]
  }
]
```

### Sin Crear IAM Role (rol existente)

```hcl
inputs = {
  environment     = "production"
  create_iam_role = false  # No crear rol, usar uno existente

  aws_accounts = {
    "prod" = {
      name           = "CloudWatch - Production"
      account_id     = "111111111111"
      default_region = "us-east-1"
      enabled        = true
      is_default     = true
    }
  }
}
```

## Variables

### Variables Principales

| Variable | Tipo | Descripción | Default |
|----------|------|-------------|---------|
| `environment` | string | Nombre del ambiente | - |
| `create_iam_role` | bool | Crear IAM Role automáticamente | `true` |
| `iam_role_name` | string | Nombre del IAM Role | `"GrafanaCloudWatchRole"` |
| `grafana_cloud_account_id` | string | Account ID de Grafana Cloud | `""` |
| `external_id` | string | External ID para assume role | `""` |
| `aws_accounts` | map(object) | Mapa de cuentas AWS | `{}` |

### Estructura de `aws_accounts`

| Campo | Tipo | Descripción | Requerido |
|-------|------|-------------|-----------|
| `name` | string | Nombre del data source en Grafana | ✅ |
| `account_id` | string | Account ID de AWS | ✅ |
| `auth_type` | string | Tipo de auth: `default`, `keys`, `ec2_iam_role` | No |
| `default_region` | string | Región AWS por defecto | ✅ |
| `enabled` | bool | Si el data source está habilitado | No |
| `is_default` | bool | Si es el data source por defecto | No |
| `custom_metrics_namespaces` | string | Namespaces custom separados por coma | No |
| `labels` | map(string) | Labels adicionales | No |

## Outputs

| Output | Descripción |
|--------|-------------|
| `iam_role_arn` | ARN del IAM Role creado |
| `iam_role_name` | Nombre del IAM Role |
| `iam_policy_arn` | ARN de la IAM Policy |
| `datasource_ids` | IDs de los data sources creados |
| `datasource_uids` | UIDs de los data sources creados |
| `datasource_details` | Detalles completos de los data sources |
| `role_arns_by_account` | Mapa de ARNs de roles por cuenta |

## Ejecución

```bash
# Desde el directorio del ambiente
cd prod/aws-cloudwatch-collector

# Inicializar
terragrunt init

# Ver plan
terragrunt plan

# Aplicar
terragrunt apply
```

## Permisos del IAM Role

El módulo crea un IAM Role con los siguientes permisos:

### CloudWatch Metrics
- `cloudwatch:DescribeAlarmsForMetric`
- `cloudwatch:DescribeAlarmHistory`
- `cloudwatch:DescribeAlarms`
- `cloudwatch:ListMetrics`
- `cloudwatch:GetMetricStatistics`
- `cloudwatch:GetMetricData`
- `cloudwatch:GetInsightRuleReport`

### CloudWatch Logs
- `logs:DescribeLogGroups`
- `logs:GetLogGroupFields`
- `logs:StartQuery`
- `logs:StopQuery`
- `logs:GetQueryResults`
- `logs:GetLogEvents`
- `logs:FilterLogEvents`

### Otros
- `ec2:DescribeRegions` (para el selector de región)
- `tag:GetResources` (para filtrar por tags)

## Múltiples Cuentas AWS (Cross-Account)

Para monitorear múltiples cuentas AWS:

### Opción 1: Crear el rol en cada cuenta

Ejecuta el módulo en cada cuenta AWS donde quieras crear el rol:

```bash
# Cuenta 1
AWS_PROFILE=account1 terragrunt apply

# Cuenta 2
AWS_PROFILE=account2 terragrunt apply
```

### Opción 2: Crear rol solo en cuenta principal

1. Crea el rol en la cuenta principal con `create_iam_role = true`
2. En las otras cuentas, crea el rol manualmente con la misma trust policy
3. Usa `create_iam_role = false` para esas cuentas

## Troubleshooting

### Error: "Access Denied" o "AssumeRole failed"

1. Verifica que `grafana_cloud_account_id` es correcto
2. Verifica que `external_id` coincide exactamente con el de Grafana Cloud
3. Verifica que el IAM Role fue creado correctamente

### Error: "Invalid region"

Verifica que `default_region` es una región AWS válida (ej: `us-east-1`, `eu-west-1`).

### No aparecen métricas en Grafana

1. Espera unos minutos después de crear el data source
2. Verifica que hay métricas en CloudWatch en la región especificada
3. Prueba la conexión desde Grafana: Data Sources → CloudWatch → Test

### Error: "grafana_cloud_account_id is required"

Debes proporcionar el Account ID de Grafana Cloud. Obtenerlo desde:
Grafana Cloud → Connections → Data sources → Add CloudWatch → Assume Role

## Referencias

- [Documentación de Grafana CloudWatch Data Source](https://grafana.com/docs/grafana-cloud/connect-externally-hosted/data-sources/aws-cloudwatch/)
- [Terraform Grafana Provider](https://registry.terraform.io/providers/grafana/grafana/latest/docs/resources/data_source)
- [AWS IAM Assume Role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use.html)
- [External ID Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user_externalid.html)
