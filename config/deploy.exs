import Config

# Deployment configuration for Mix.Tasks.Deploy
# See: lib/mix/tasks/deploy.ex

# Shared configuration across all environments
config :deploy,
  repository: "git@github.com:toreyheinz/spotlightwm.git",
  shared_dirs: ["tmp", "logs"],
  shared_files: [".env"],
  build_script: "./build.sh",
  app_name: "spotlight"

# Production environment configuration
config :deploy, :production,
  branch: "main",
  user: "dev",
  domain: "ssh.teagles.io",
  port: 22,
  deploy_to: "/var/www/www.spotlightwm.org",
  url: "https://www.spotlightwm.org",
  app_port: 4006
