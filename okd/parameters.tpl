parameters:
- description: Application name
  displayName: Application name
  name: APP
  required: true
- description: Environment
  displayName: Environment
  name: ENV
  required: true
- description: public ingress hostname
  displayName: hostname
  name: HOSTNAME
  required: true
- description: Healthcheck url
  displayName: Healthcheck url
  name: HEALTH_URL
  required: true
- description: Subject DN header
  displayName: X-SSL-Client-S-DN
  name: XSslClientSDN 
  value: '${ssl_client_s_dn}'
- description: Application config.yaml
  displayName: Application config.yaml
  name: CONFIG
  required: true
