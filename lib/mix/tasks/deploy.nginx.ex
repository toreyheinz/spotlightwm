defmodule Mix.Tasks.Deploy.Nginx do
  use Mix.Task

  @shortdoc "Update NGINX configuration on server"
  @moduledoc """
  Update NGINX configuration for the deployed Phoenix application.

  ## Usage

      mix deploy.nginx                # Update nginx config for production
      mix deploy.nginx staging        # Update nginx config for staging

  This task will:
  1. Upload the nginx configuration from deploy/nginx.conf
  2. Replace template variables with actual values
  3. Test the configuration
  4. Reload nginx if the test passes
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
          Logger.error("Too many arguments. Usage: mix deploy.nginx [environment]")
          exit(1)
      end

    config = get_deploy_config(env)

    Logger.info("Updating NGINX configuration for #{env} environment...")

    with :ok <- check_requirements(config),
         :ok <- upload_nginx_config(config),
         :ok <- test_nginx_config(config),
         :ok <- reload_nginx(config) do
      Logger.info("✅ NGINX configuration updated successfully!")
    else
      {:error, reason} ->
        Logger.error("❌ Failed to update NGINX configuration: #{reason}")
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
    required_keys = [:user, :domain, :url, :app_port, :app_name]
    missing = Enum.filter(required_keys, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing) do
      :ok
    else
      {:error, "Missing required config keys: #{inspect(missing)}"}
    end
  end

  defp upload_nginx_config(config) do
    # Check for nginx.conf in deploy directory
    nginx_files = Path.wildcard("deploy/nginx*.conf")

    nginx_file =
      cond do
        "deploy/nginx.conf" in nginx_files -> "deploy/nginx.conf"
        length(nginx_files) > 0 -> hd(nginx_files)
        true -> nil
      end

    if nginx_file do
      # Extract server name from URL - used as nginx config name for uniqueness
      server_name = URI.parse(config.url).host || "localhost"

      # SSL domain - could be different from server name for wildcard certs
      ssl_domain = Map.get(config, :ssl_domain, server_name)

      Logger.info("Uploading nginx configuration from #{nginx_file} for #{server_name}...")

      # Read template
      template = File.read!(nginx_file)

      # Create unique upstream name from server_name (replace dots/dashes with underscores)
      upstream_name = server_name |> String.replace(~r/[.-]/, "_")

      # Replace variables
      content =
        template
        |> String.replace("${APP_NAME}", config.app_name)
        |> String.replace("${APP_PORT}", to_string(config.app_port))
        |> String.replace("${SERVER_NAME}", server_name)
        |> String.replace("${SSL_DOMAIN}", ssl_domain)
        |> String.replace("${UPSTREAM_NAME}", upstream_name)
        |> String.replace(
          "${DEPLOY_TO}",
          Map.get(config, :deploy_to, "/var/www/#{config.app_name}")
        )

      # Create temp file - use server_name for unique filenames per environment
      temp_file = Path.join(System.tmp_dir!(), "nginx-#{server_name}.conf")
      File.write!(temp_file, content)

      # Upload to server
      remote_temp = "/tmp/nginx-#{server_name}.conf"

      case scp_upload(config, temp_file, remote_temp) do
        {_, 0} ->
          # Move to sites-available - use server_name as config name
          move_cmd = """
          sudo cp #{remote_temp} /etc/nginx/sites-available/#{server_name} && \
          sudo ln -sf /etc/nginx/sites-available/#{server_name} /etc/nginx/sites-enabled/#{server_name}
          """

          case ssh_exec(config, move_cmd) do
            {_, 0} ->
              File.rm(temp_file)
              :ok

            {output, _} ->
              File.rm(temp_file)
              {:error, "Failed to install nginx config: #{output}"}
          end

        {output, _} ->
          File.rm(temp_file)
          {:error, "Failed to upload nginx config: #{output}"}
      end
    else
      {:error, "No nginx configuration file found in deploy/"}
    end
  end

  defp test_nginx_config(config) do
    Logger.info("Testing nginx configuration...")

    case ssh_exec(config, "sudo nginx -t") do
      {output, 0} ->
        Logger.info(output)
        :ok

      {output, _} ->
        {:error, "Nginx configuration test failed: #{output}"}
    end
  end

  defp reload_nginx(config) do
    Logger.info("Reloading nginx...")

    case ssh_exec(config, "sudo systemctl reload nginx") do
      {_, 0} ->
        :ok

      {output, _} ->
        {:error, "Failed to reload nginx: #{output}"}
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
