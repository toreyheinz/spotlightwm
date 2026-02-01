defmodule Mix.Tasks.Deploy.Service do
  use Mix.Task

  @shortdoc "Update systemd service on server"
  @moduledoc """
  Update systemd service configuration for the deployed Phoenix application.

  ## Usage

      mix deploy.service                # Update service for production
      mix deploy.service staging        # Update service for staging

  This task will:
  1. Upload the service file from deploy/
  2. Replace template variables with actual values
  3. Reload systemd daemon
  4. Restart the service
  """

  require Logger

  @impl Mix.Task
  def run(args) do
    # Load deployment config
    Mix.Task.run("loadconfig", ["config/deploy.exs"])

    env =
      case args do
        [] ->
          :production

        [env] ->
          String.to_atom(env)

        _ ->
          Logger.error("Too many arguments. Usage: mix deploy.service [environment]")
          exit(1)
      end

    config = get_deploy_config(env)

    Logger.info("Updating systemd service for #{env} environment...")

    with :ok <- check_requirements(config),
         :ok <- upload_service_file(config),
         :ok <- reload_and_restart_service(config) do
      Logger.info("✅ Systemd service updated successfully!")
    else
      {:error, reason} ->
        Logger.error("❌ Failed to update systemd service: #{reason}")
        exit(1)
    end
  end

  defp get_deploy_config(env) do
    base_config = Application.get_all_env(:deploy)
    env_config = Keyword.get(base_config, env, [])

    if env_config == [] do
      Logger.error("No configuration found for environment: #{env}")
      exit(1)
    end

    # Extract app name from config or fallback to Mix project app name
    app_name = Keyword.get(base_config, :app_name) || Mix.Project.config()[:app] |> to_string()

    # Merge configs
    base_config
    |> Keyword.delete(:production)
    |> Keyword.delete(:staging)
    |> Keyword.merge(env_config)
    |> Keyword.put(:env, env)
    |> Keyword.put(:app_name, app_name)
    |> Map.new()
  end

  defp check_requirements(config) do
    required_keys = [:user, :domain, :deploy_to, :app_port, :app_name]
    missing = Enum.filter(required_keys, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required config keys: #{inspect(missing)}"}
    end
  end

  defp upload_service_file(config) do
    # Look for service file
    service_files = Path.wildcard("deploy/*.service")

    service_file =
      case service_files do
        [] ->
          nil

        [file] ->
          file

        files ->
          # Prefer one that matches app name
          Enum.find(files, hd(files), &String.contains?(&1, config.app_name))
      end

    if service_file do
      # Service name is {app_name}-{env} (e.g., testapp-staging, testapp-production)
      service_name = "#{config.app_name}-#{config.env}"

      Logger.info("Uploading service file from #{service_file} as #{service_name}...")

      # Read template
      template = File.read!(service_file)

      # Extract host from URL
      host =
        case URI.parse(Map.get(config, :url, "")) do
          %{host: nil} -> "localhost"
          %{host: h} -> h
        end

      # Replace variables
      content =
        template
        |> String.replace(
          "${DEPLOY_TO}",
          Map.get(config, :deploy_to, "/var/www/#{config.app_name}")
        )
        |> String.replace("${APP_PORT}", to_string(config.app_port))
        |> String.replace("${PHX_HOST}", host)

      # Ensure PHX_SERVER=true is set
      content =
        if not String.contains?(content, "PHX_SERVER") do
          String.replace(
            content,
            "Environment=\"PORT=",
            "Environment=\"PHX_SERVER=true\"\nEnvironment=\"PORT="
          )
        else
          content
        end

      # Create temp file
      temp_file = Path.join(System.tmp_dir!(), "#{service_name}.service")
      File.write!(temp_file, content)

      # Upload to server
      remote_temp = "/tmp/#{service_name}.service"

      case scp_upload(config, temp_file, remote_temp) do
        {_, 0} ->
          # Install service
          install_cmd = """
          sudo cp #{remote_temp} /etc/systemd/system/#{service_name}.service && \
          sudo systemctl daemon-reload
          """

          case ssh_exec(config, install_cmd) do
            {_, 0} ->
              File.rm(temp_file)
              :ok

            {output, _} ->
              File.rm(temp_file)
              {:error, "Failed to install service: #{output}"}
          end

        {output, _} ->
          File.rm(temp_file)
          {:error, "Failed to upload service file: #{output}"}
      end
    else
      {:error, "No service file found in deploy/"}
    end
  end

  defp reload_and_restart_service(config) do
    # Service name is {app_name}-{env} (e.g., testapp-staging, testapp-production)
    service_name = "#{config.app_name}-#{config.env}"

    Logger.info("Restarting service: #{service_name}")

    restart_cmd = """
    sudo systemctl daemon-reload && \
    sudo systemctl restart #{service_name} && \
    sudo systemctl status #{service_name} | head -n 10
    """

    case ssh_exec(config, restart_cmd) do
      {output, 0} ->
        Logger.info(output)
        :ok

      {output, _} ->
        {:error, "Failed to restart service: #{output}"}
    end
  end

  defp ssh_exec(config, command) do
    port_opt = if config.port && config.port != 22, do: "-p #{config.port}", else: ""

    ssh_command = """
    ssh -T -A -o ConnectTimeout=10 #{port_opt} \
    #{config.user}@#{config.domain} '#{command}'
    """

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
