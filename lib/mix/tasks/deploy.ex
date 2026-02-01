defmodule Mix.Tasks.Deploy do
  use Mix.Task

  @shortdoc "Deploy Phoenix application to VPS"
  @moduledoc """
  Deploy Phoenix application to a VPS using SSH.

  ## Usage

      mix deploy                      # Deploy to production (default)
      mix deploy staging              # Deploy to staging
      mix deploy staging feature-xyz  # Deploy specific branch to staging

  ## Configuration

  Configure deployment in `config/deploy.exs`:

      import Config

      config :deploy,
        repository: "git@github.com:username/app-name.git",
        shared_dirs: ["uploads", "tmp", "logs"],
        shared_files: [".env"],
        build_script: "./build.sh"

      config :deploy, :production,
        branch: "main",
        user: "dev",
        domain: "ssh.example.com",
        port: 22,
        deploy_to: "/var/www/app-name",
        url: "https://app.example.com",
        app_port: 4000

      config :deploy, :staging,
        branch: "develop",
        user: "dev",
        domain: "ssh.example.com",
        port: 22,
        deploy_to: "/var/www/staging.app-name",
        url: "https://staging.app.example.com",
        app_port: 4001
  """

  require Logger

  @impl Mix.Task
  def run(args) do
    # Load deployment config
    Mix.Task.run("loadconfig", ["config/deploy.exs"])

    {env, branch} = parse_args(args)
    config = get_deploy_config(env)

    # Allow branch override
    config = if branch, do: Map.put(config, :branch, branch), else: config

    Logger.info("Deploying to #{env} environment...")
    Logger.info("Branch: #{config.branch}")
    Logger.info("Host: #{config.user}@#{config.domain}:#{config.port}")
    Logger.info("Deploy to: #{config.deploy_to}")

    # Execute deployment
    with :ok <- check_requirements(config),
         {:ok, config} <- create_release_dir(config),
         :ok <- clone_or_fetch_code(config),
         :ok <- link_shared_paths(config),
         :ok <- run_build_script(config),
         :ok <- update_symlinks(config),
         :ok <- restart_service(config),
         :ok <- cleanup_old_releases(config),
         :ok <- health_check(config) do
      Logger.info("✅ Deployment completed successfully!")
    else
      {:error, reason} ->
        Logger.error("❌ Deployment failed: #{reason}")
        exit(1)
    end
  end

  defp parse_args([]), do: {:production, nil}
  defp parse_args([env]), do: {String.to_atom(env), nil}
  defp parse_args([env, branch]), do: {String.to_atom(env), branch}

  defp get_deploy_config(env) do
    base_config = Application.get_all_env(:deploy)
    env_config = Keyword.get(base_config, env, [])

    if env_config == [] do
      Logger.error("No configuration found for environment: #{env}")
      exit(1)
    end

    # Extract app name from config or fallback to Mix project app name
    app_name = Keyword.get(base_config, :app_name) || Mix.Project.config()[:app] |> to_string()

    # Merge base and environment configs
    base_config
    |> Keyword.delete(:production)
    |> Keyword.delete(:staging)
    |> Keyword.merge(env_config)
    |> Keyword.put(:env, env)
    |> Keyword.put(:app_name, app_name)
    |> Map.new()
  end

  defp check_requirements(config) do
    required_keys = [:repository, :user, :domain, :deploy_to, :branch]
    missing = Enum.filter(required_keys, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required config keys: #{inspect(missing)}"}
    end
  end

  defp create_release_dir(config) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> to_string()
    release_path = "#{config.deploy_to}/releases/#{timestamp}"

    case ssh_exec(config, "mkdir -p #{release_path}") do
      {_, 0} ->
        config = Map.put(config, :release_path, release_path)
        {:ok, config}

      {output, _} ->
        {:error, "Failed to create release directory: #{output}"}
    end
  end

  defp clone_or_fetch_code(%{release_path: release_path} = config) do
    repo_path = "#{config.deploy_to}/repo"

    # Clone or update repository
    clone_cmd = """
    if [ -d #{repo_path} ]; then
      cd #{repo_path} && git fetch origin
    else
      git clone #{config.repository} #{repo_path}
    fi
    """

    case ssh_exec(config, clone_cmd) do
      {_, 0} ->
        # Archive the specific branch to release directory (use origin/ to get fetched code)
        archive_cmd = """
        cd #{repo_path} && \
        git archive origin/#{config.branch} | tar -x -C #{release_path}
        """

        case ssh_exec(config, archive_cmd) do
          {_, 0} -> :ok
          {output, _} -> {:error, "Failed to archive code: #{output}"}
        end

      {output, _} ->
        {:error, "Failed to clone/fetch repository: #{output}"}
    end
  end

  defp link_shared_paths(%{release_path: release_path} = config) do
    shared_path = "#{config.deploy_to}/shared"

    # Create shared directories if they don't exist
    shared_dirs = Map.get(config, :shared_dirs, [])
    shared_files = Map.get(config, :shared_files, [])

    # Create shared structure
    create_shared_cmd = """
    mkdir -p #{shared_path} && \
    #{Enum.map(shared_dirs, fn dir -> "mkdir -p #{shared_path}/#{dir}" end) |> Enum.join(" && ")}
    """

    case ssh_exec(config, create_shared_cmd) do
      {_, 0} ->
        # Link shared directories
        link_dirs_cmd =
          shared_dirs
          |> Enum.map(fn dir ->
            "ln -nfs #{shared_path}/#{dir} #{release_path}/#{dir}"
          end)
          |> Enum.join(" && ")

        # Link shared files
        link_files_cmd =
          shared_files
          |> Enum.map(fn file ->
            dir = Path.dirname(file)

            "mkdir -p #{release_path}/#{dir} && " <>
              "if [ -f #{shared_path}/#{file} ]; then " <>
              "ln -nfs #{shared_path}/#{file} #{release_path}/#{file}; " <>
              "fi"
          end)
          |> Enum.join(" && ")

        commands =
          [link_dirs_cmd, link_files_cmd]
          |> Enum.reject(&(&1 == ""))

        if Enum.empty?(commands) do
          :ok
        else
          full_cmd = Enum.join(commands, " && ")

          case ssh_exec(config, full_cmd) do
            {_, 0} -> :ok
            {output, _} -> {:error, "Failed to link shared paths: #{output}"}
          end
        end

      {output, _} ->
        {:error, "Failed to create shared directories: #{output}"}
    end
  end

  defp run_build_script(%{release_path: release_path} = config) do
    build_script = Map.get(config, :build_script, "./build.sh")

    Logger.info("Running build script...")

    # First make it executable
    chmod_cmd = "chmod +x #{release_path}/#{build_script}"

    case ssh_exec(config, chmod_cmd) do
      {_, 0} ->
        # Run the build script with explicit bash to ensure profile is loaded
        build_cmd = "cd #{release_path} && /bin/bash -l -c '#{build_script}'"

        case ssh_exec(config, build_cmd) do
          {_, 0} -> :ok
          {output, _} -> {:error, "Build failed: #{output}"}
        end

      {output, _} ->
        {:error, "Failed to make build script executable: #{output}"}
    end
  end

  defp update_symlinks(%{release_path: release_path} = config) do
    current_path = "#{config.deploy_to}/current"

    # Update current symlink atomically
    update_cmd = """
    ln -nfs #{release_path} #{current_path}.tmp && \
    mv -Tf #{current_path}.tmp #{current_path}
    """

    case ssh_exec(config, update_cmd) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Failed to update symlinks: #{output}"}
    end
  end

  defp restart_service(config) do
    # Service name is {app_name}-{env} (e.g., testapp-staging, testapp-production)
    service_name = "#{config.app_name}-#{config.env}"

    restart_cmd = """
    sudo systemctl daemon-reload && \
    sudo systemctl restart #{service_name} && \
    sudo systemctl status #{service_name} | head -n 10
    """

    Logger.info("Restarting service: #{service_name}")

    case ssh_exec(config, restart_cmd) do
      {output, 0} ->
        Logger.info(output)
        :ok

      {output, _} ->
        {:error, "Failed to restart service: #{output}"}
    end
  end

  defp cleanup_old_releases(config) do
    # Keep only the last 5 releases
    cleanup_cmd = """
    cd #{config.deploy_to}/releases && \
    ls -t | tail -n +6 | xargs -r rm -rf
    """

    case ssh_exec(config, cleanup_cmd) do
      {_, 0} ->
        :ok

      {_, _} ->
        Logger.warning("Failed to cleanup old releases")
        # Don't fail deployment for cleanup
        :ok
    end
  end

  defp health_check(config) do
    if url = Map.get(config, :url) do
      Logger.info("Performing health check...")

      health_cmd = "curl -fsSL -o /dev/null -w '%{http_code}' --retry 3 --retry-delay 2 #{url}"

      case ssh_exec(config, health_cmd) do
        {"200", 0} ->
          Logger.info("✅ Health check passed!")
          :ok

        {status, 0} ->
          Logger.warning("Health check returned status: #{status}")
          # Don't fail for non-200 status
          :ok

        {output, _} ->
          Logger.warning("Health check failed: #{output}")
          # Don't fail deployment for health check
          :ok
      end
    else
      :ok
    end
  end

  defp ssh_exec(config, command, _opts \\ []) do
    port_opt = if config.port && config.port != 22, do: "-p #{config.port}", else: ""

    ssh_command = """
    ssh -T -A -o ConnectTimeout=10 #{port_opt} \
    #{config.user}@#{config.domain} '#{command}'
    """

    Logger.debug("SSH command: #{inspect(ssh_command)}")
    Logger.debug("Remote command: #{inspect(command)}")

    System.cmd("bash", ["-c", ssh_command], stderr_to_stdout: true)
  end

  defp scp_upload(config, local_file, remote_file) do
    port_opt = if config.port && config.port != 22, do: "-P #{config.port}", else: ""

    scp_command = """
    scp #{port_opt} #{local_file} \
    #{config.user}@#{config.domain}:#{remote_file}
    """

    System.cmd("bash", ["-c", scp_command], stderr_to_stdout: true)
  end
end
