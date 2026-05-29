# ==============================================================================
# PHASE 7: ADVANCED INGRESS & TLS (BONUS)
# ==============================================================================

# Create a self-signed certificate for the ALB since nip.io cannot be DNS-validated via ACM
resource "tls_private_key" "ingress_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ingress_cert" {
  private_key_pem = tls_private_key.ingress_key.private_key_pem

  subject {
    common_name  = "project-bedrock.local"
    organization = "InnovateMart"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "ingress_cert" {
  private_key      = tls_private_key.ingress_key.private_key_pem
  certificate_body = tls_self_signed_cert.ingress_cert.cert_pem

  tags = {
    Project = "karatu-2025-capstone"
  }
}
