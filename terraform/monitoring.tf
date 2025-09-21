# Make sure to update YOUR_DOMAIN to match the build.sh script

variable "kube_monitoring_stack_values" {
  type    = string
  default = <<-EOF
    grafana:
      adminUser: admin
      adminPassword: admin
      enabled: true
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt-production
        hosts:
          - grafana.disslite.com
        tls:
          - secretName: grafana-tls
            hosts:
              - grafana.disslite.com

    alertmanager:
      enabled: true
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt-production
        hosts:
          - alertmanager.disslite.com
        tls:
          - secretName: alertmanager-tls
            hosts:
              - alertmanager.disslite.com

    prometheus:
      enabled: true
      ingress:
        enabled: true
        ingressClassName: nginx
        annotations:
          cert-manager.io/cluster-issuer: letsencrypt-production
        hosts:
          - prometheus.disslite.com
        tls:
          - secretName: prometheus-tls
            hosts:
              - prometheus.disslite.com
      prometheusSpec:
        replicas: 2
        replicaExternalLabelName: prometheus_replica
        prometheusExternalLabelName: prometheus_cluster
        enableAdminAPI: false
        logFormat: logfmt
        logLevel: info
        retention: 120h
        serviceMonitorSelectorNilUsesHelmValues: false
        serviceMonitorNamespaceSelector: {}
        serviceMonitorSelector: {}
        resources:
          limits:
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 2Gi

    prometheus-node-exporter:
      resources:
        limits:
          memory: 30Mi
        requests:
          cpu: 20m
          memory: 30Mi

    kube-state-metrics:
      resources:
        limits:
          memory: 300Mi
        requests:
          cpu: 10m
          memory: 300Mi

    prometheusOperator:
      resources:
        limits:
          memory: 400Mi
        requests:
          cpu: 10m
          memory: 400Mi
    EOF
}

# Monitoring stack will be deployed via Helm CLI
resource "helm_release" "kube_monitoring_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = "61.6.0"

  create_namespace = true

  values = [var.kube_monitoring_stack_values]
}