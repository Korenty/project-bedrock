# ==============================================================================
# PHASE 6: APPLICATION DEPLOYMENT (HELM)
# ==============================================================================

# Create Namespace for the application
resource "kubernetes_namespace" "retail_app" {
  metadata {
    name = "retail-app"
  }
}

# Create IAM role for carts (IRSA)
data "aws_iam_policy_document" "carts_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:retail-app:carts"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "carts" {
  name               = "project-bedrock-carts-role"
  assume_role_policy = data.aws_iam_policy_document.carts_assume_role.json
}

resource "aws_iam_role_policy_attachment" "carts_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.carts.name
}

# Create Kubernetes Secrets for the RDS databases
resource "kubernetes_secret" "catalog_db" {
  metadata {
    name      = "catalog-db-secret"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    username = "catalog_user"
    password = random_password.mysql_password.result
  }
}

resource "kubernetes_secret" "orders_db" {
  metadata {
    name      = "orders-db-secret"
    namespace = kubernetes_namespace.retail_app.metadata[0].name
  }

  data = {
    username = "orders_user"
    password = random_password.postgres_password.result
  }
}

# Deploy the application using Helm
resource "helm_release" "retail_app" {
  name      = "retail-app"
  chart     = "${path.module}/../kubernetes/retail-store-sample-chart"
  namespace = kubernetes_namespace.retail_app.metadata[0].name

  # --- CATALOG OVERRIDES ---
  set {
    name  = "catalog.mysql.create"
    value = "false"
  }
  set {
    name  = "catalog.mysql.endpoint"
    value = aws_db_instance.mysql.endpoint
  }
  set {
    name  = "catalog.mysql.database"
    value = aws_db_instance.mysql.db_name
  }
  set {
    name  = "catalog.mysql.secret.name"
    value = kubernetes_secret.catalog_db.metadata[0].name
  }
  set {
    name  = "catalog.mysql.secret.create"
    value = "false"
  }

  # --- ORDERS OVERRIDES ---
  set {
    name  = "orders.postgresql.create"
    value = "false"
  }
  set {
    name  = "orders.postgresql.endpoint.host"
    value = split(":", aws_db_instance.postgres.endpoint)[0]
  }
  set {
    name  = "orders.postgresql.endpoint.port"
    value = "5432"
  }
  set {
    name  = "orders.postgresql.database"
    value = aws_db_instance.postgres.db_name
  }
  set {
    name  = "orders.postgresql.secret.name"
    value = kubernetes_secret.orders_db.metadata[0].name
  }
  set {
    name  = "orders.postgresql.secret.create"
    value = "false"
  }

  # --- CARTS OVERRIDES ---
  set {
    name  = "cart.dynamodb.create"
    value = "false"
  }
  set {
    name  = "cart.dynamodb.tableName"
    value = aws_dynamodb_table.carts_table.name
  }
  set {
    name  = "cart.serviceAccount.create"
    value = "true"
  }
  set {
    name  = "cart.serviceAccount.name"
    value = "carts"
  }
  set {
    name  = "cart.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.carts.arn
  }

  # --- UI INGRESS OVERRIDES ---
  set {
    name  = "ui.endpoints.catalog"
    value = "http://retail-app-catalog:80"
  }
  set {
    name  = "ui.endpoints.carts"
    value = "http://retail-app-carts:80"
  }
  set {
    name  = "ui.endpoints.checkout"
    value = "http://retail-app-checkout:80"
  }
  set {
    name  = "ui.endpoints.orders"
    value = "http://retail-app-orders:80"
  }
  set {
    name  = "ui.endpoints.assets"
    value = "http://retail-app-assets:80"
  }
  set {
    name  = "checkout.endpoints.orders"
    value = "http://retail-app-orders:80"
  }

  set {
    name  = "ui.ingress.enabled"
    value = "true"
  }
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/certificate-arn"
    value = aws_acm_certificate.ingress_cert.arn
  }
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\": 80}\\, {\"HTTPS\":443}]"
    type  = "string"
  }
  set {
    name  = "ui.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/ssl-redirect"
    value = "443"
    type  = "string"
  }
  set {
    name  = "ui.ingress.className"
    value = "alb"
  }

  depends_on = [
    module.eks,
    aws_db_instance.mysql,
    aws_db_instance.postgres,
    aws_dynamodb_table.carts_table,
    helm_release.lbc
  ]
}
