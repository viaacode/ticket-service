parameters:
- description: Application name
  displayName: Application name
  name: APP
  required: true
- description: Environment
  displayName: Environment
  name: ENV
  required: true
- description: ImageStream Tag
  displayName: ImageStream Tag
  name: TAG
  required: true
- description: Source git repository url
  displayName: Source Url
  name: SOURCE_URL
  required: true
- description: Healthcheck url
  displayName: Healthcheck url
  name: HEALTH_URL
  required: true
- description: Application config.yaml
  displayName: Application config.yaml
  name: CONFIG
  required: true
- description: Source repo username
  displayName: Source repo username
  name: SOURCE_USERNAME
  required: true
- description: Source repo password
  displayName: Source repo password
  name: SOURCE_PASSWORD
  required: true
- description: Build Trigger Secret
  displayName: Build Trigger Secret
  name: BUILD_TRIGGER_SECRET
  required: true
