defmodule Mix.Tasks.Deploy.Setup do
  use Mix.Task

  @shortdoc "Setup Phoenix application on VPS for first deployment"
  @moduledoc """
  Initial setup for Phoenix application deployment on VPS.

  This task will:
  - Create application directory structure
  - Create PostgreSQL database and user
  - Install systemd service
  - Configure NGINX
  - Create shared directories and files

  ## Usage

      mix deploy.setup production
      mix deploy.setup staging

  ## Requirements

  - Deployment configuration in `config/deploy.exs`
  - Systemd service file in `deploy/app-name.service`
  - NGINX config in `deploy/nginx.conf`
  """

  require Logger

  @impl Mix.Task
  def run(args) do
    # Load deployment config
    Mix.Task.run("loadconfig", ["config/deploy.exs"])
    
    env = parse_args(args)
    config = get_deploy_config(env)
    
    # Extract app name from config or fallback to Mix project app name
    app_name = Map.get(config, :app_name) || (Mix.Project.config()[:app] |> to_string())
    config = Map.put(config, :app_name, app_name)
    
    Logger.info("Setting up #{app_name} for #{env} environment...")
    Logger.info("Host: #{config.user}@#{config.domain}:#{config.port}")
    Logger.info("Deploy to: #{config.deploy_to}")
    
    # Execute setup steps
    with :ok <- check_requirements(config),
         :ok <- create_directory_structure(config),
         {:ok, config} <- maybe_setup_postgresql(config, env),
         :ok <- create_env_file(config, env),
         :ok <- install_systemd_service(config),
         :ok <- configure_nginx(config),
         :ok <- create_shared_files(config) do
      Logger.info("✅ Setup completed successfully!")
      Logger.info("")
      Logger.info("Next steps:")
      Logger.info("1. Update #{config.deploy_to}/shared/.env.prod.exs with your secrets")
      Logger.info("2. Enable and start the service: sudo systemctl enable #{app_name}-phoenix")
      Logger.info("3. Run: mix deploy #{env}")
    else
      {:error, reason} ->
        Logger.error("❌ Setup failed: #{reason}")
        exit(1)
    end
  end

  defp parse_args([]), do: :production
  defp parse_args([env]), do: String.to_atom(env)

  defp get_deploy_config(env) do
    base_config = Application.get_all_env(:deploy)
    env_config = Keyword.get(base_config, env, [])
    
    if env_config == [] do
      Logger.error("No configuration found for environment: #{env}")
      exit(1)
    end
    
    # Merge base and environment configs
    base_config
    |> Keyword.delete(:production)
    |> Keyword.delete(:staging)
    |> Keyword.merge(env_config)
    |> Map.new()
  end

  defp check_requirements(config) do
    required_keys = [:user, :domain, :deploy_to, :app_port]
    missing = Enum.filter(required_keys, &(not Map.has_key?(config, &1)))
    
    if Enum.empty?(missing) do
      # Check for local files
      # Look for any .service file in deploy directory
      service_files = Path.wildcard("deploy/*.service")
      if Enum.empty?(service_files) do
        {:error, "Missing systemd service file in deploy/ directory"}
      else
        :ok
      end
    else
      {:error, "Missing required config keys: #{inspect(missing)}"}
    end
  end

  defp create_directory_structure(config) do
    dirs = [
      config.deploy_to,
      "#{config.deploy_to}/releases",
      "#{config.deploy_to}/shared",
      "#{config.deploy_to}/shared/config",
      "#{config.deploy_to}/shared/logs",
      "#{config.deploy_to}/shared/tmp",
      "#{config.deploy_to}/shared/uploads"
    ]
    
    # Use sudo to create directories and then chown to the deploy user
    create_cmd = """
    sudo mkdir -p #{Enum.join(dirs, " ")} && \
    sudo chown -R #{config.user}:#{config.user} #{config.deploy_to}
    """
    
    case ssh_exec(config, create_cmd) do
      {_, 0} -> :ok
      {output, _} -> {:error, "Failed to create directories: #{output}"}
    end
  end

  defp maybe_setup_postgresql(config, env) do
    # Check if app uses Ecto/database
    if Code.ensure_loaded?(Ecto) && function_exported?(Module.concat([config.app_name |> String.capitalize(), "Repo"]), :__info__, 1) do
      setup_postgresql(config, env)
    else
      Logger.info("No database configuration needed for this app")
      {:ok, config}
    end
  end

  defp setup_postgresql(config, env) do
    db_name = "#{config.app_name}_#{env}"
    db_user = config.app_name
    db_pass = generate_password()
    
    Logger.info("Creating PostgreSQL database: #{db_name}")
    Logger.info("Database user: #{db_user}")
    
    # Create user and database
    psql_commands = """
    sudo -u postgres psql <<EOF
    -- Create user if not exists
    DO \\$\\$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '#{db_user}') THEN
        CREATE USER #{db_user} WITH PASSWORD '#{db_pass}';
      END IF;
    END
    \\$\\$;
    
    -- Create database if not exists
    SELECT 'CREATE DATABASE #{db_name} OWNER #{db_user}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '#{db_name}')\\gexec
    
    -- Grant all privileges
    GRANT ALL PRIVILEGES ON DATABASE #{db_name} TO #{db_user};
    EOF
    """
    
    case ssh_exec(config, psql_commands) do
      {_, 0} -> 
        # Store credentials for later
        updated_config = Map.merge(config, %{
          db_name: db_name,
          db_user: db_user,
          db_pass: db_pass
        })
        {:ok, updated_config}
      {output, _} -> 
        {:error, "Failed to setup PostgreSQL: #{output}"}
    end
  end

  defp create_env_file(%{db_name: db_name, db_user: db_user, db_pass: db_pass} = config, _env) do
    env_content = """
    import Config
    
    # Database configuration
    config :#{config.app_name}, #{String.capitalize(config.app_name)}.Repo,
      username: "#{db_user}",
      password: "#{db_pass}",
      database: "#{db_name}",
      hostname: "localhost",
      pool_size: 10
    
    # Endpoint configuration
    config :#{config.app_name}, #{String.capitalize(config.app_name)}Web.Endpoint,
      http: [port: #{config.app_port}],
      url: [host: "#{URI.parse(config.url || "").host || "localhost"}", port: 443, scheme: "https"],
      secret_key_base: "#{generate_secret_key_base()}"
    
    # Add your other production secrets here
    # config :#{config.app_name}, :api_key, "your-api-key"
    """
    
    env_file = "#{config.deploy_to}/shared/.env.prod.exs"
    
    # Write file content via SSH
    write_cmd = """
    cat > #{env_file} << 'EOF'
    #{env_content}
    EOF
    """
    
    case ssh_exec(config, write_cmd) do
      {_, 0} ->
        Logger.info("Created environment file: #{env_file}")
        Logger.info("Database password: #{db_pass}")
        :ok
      {output, _} ->
        {:error, "Failed to create env file: #{output}"}
    end
  end

  defp create_env_file(config, _env) do
    # Create minimal env file for apps without database
    env_content = """
    import Config
    
    # Endpoint configuration
    config :#{config.app_name}, #{String.capitalize(config.app_name)}Web.Endpoint,
      http: [port: #{config.app_port}],
      url: [host: "#{URI.parse(config.url || "").host || "localhost"}", port: 443, scheme: "https"],
      secret_key_base: "#{generate_secret_key_base()}"
    
    # Add your production secrets here
    # config :#{config.app_name}, :api_key, "your-api-key"
    """
    
    env_file = "#{config.deploy_to}/shared/.env.prod.exs"
    
    write_cmd = """
    cat > #{env_file} << 'EOF'
    #{env_content}
    EOF
    """
    
    case ssh_exec(config, write_cmd) do
      {_, 0} ->
        Logger.info("Created environment file: #{env_file}")
        :ok
      {output, _} ->
        {:error, "Failed to create env file: #{output}"}
    end
  end

  defp install_systemd_service(config) do
    service_name = "#{config.app_name}-phoenix"
    # Find the first service file in deploy directory
    service_files = Path.wildcard("deploy/*.service")
    service_file = List.first(service_files)
    
    if service_file && File.exists?(service_file) do
      # Read and update service file
      service_content = File.read!(service_file)
      |> String.replace("${DEPLOY_TO}", config.deploy_to)
      |> String.replace("${APP_NAME}", config.app_name)
      |> String.replace("${APP_PORT}", to_string(config.app_port))
      |> String.replace("${USER}", config.user)
      
      # Write temporary service file
      temp_file = "/tmp/#{service_name}.service"
      File.write!(temp_file, service_content)
      
      # Upload and install service
      remote_file = "#{config.deploy_to}/shared/#{service_name}.service"
      
      case scp_upload(config, temp_file, remote_file) do
        {_, 0} ->
          install_cmd = """
          sudo ln -sf #{remote_file} /etc/systemd/system/#{service_name}.service && \
          sudo systemctl daemon-reload
          """
          
          case ssh_exec(config, install_cmd) do
            {_, 0} ->
              Logger.info("Installed systemd service: #{service_name}")
              :ok
            {output, _} ->
              {:error, "Failed to install systemd service: #{output}"}
          end
        {output, _} ->
          {:error, "Failed to upload service file: #{output}"}
      end
    else
      # Create default service file
      create_default_service(config)
    end
  end

  defp create_default_service(config) do
    service_name = "#{config.app_name}-phoenix"
    
    service_content = """
    [Unit]
    Description=#{config.app_name} Phoenix Application
    After=network.target postgresql.service
    
    [Service]
    Type=simple
    User=#{config.user}
    Group=#{config.user}
    WorkingDirectory=#{config.deploy_to}/current
    
    # Using ASDF for Elixir
    Environment="MIX_ENV=prod"
    Environment="PORT=#{config.app_port}"
    Environment="LANG=en_US.UTF-8"
    
    ExecStart=/bin/bash -lc 'source ~/.asdf/asdf.sh && #{config.deploy_to}/current/_build/prod/rel/#{config.app_name}/bin/#{config.app_name} start'
    ExecStop=/bin/bash -lc 'source ~/.asdf/asdf.sh && #{config.deploy_to}/current/_build/prod/rel/#{config.app_name}/bin/#{config.app_name} stop'
    
    Restart=on-failure
    RestartSec=5
    
    # Logging
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=#{config.app_name}
    
    [Install]
    WantedBy=multi-user.target
    """
    
    write_cmd = """
    cat > #{config.deploy_to}/shared/#{service_name}.service << 'EOF'
    #{service_content}
    EOF
    """
    
    case ssh_exec(config, write_cmd) do
      {_, 0} ->
        install_cmd = """
        sudo ln -sf #{config.deploy_to}/shared/#{service_name}.service /etc/systemd/system/#{service_name}.service && \
        sudo systemctl daemon-reload
        """
        
        case ssh_exec(config, install_cmd) do
          {_, 0} ->
            Logger.info("Created and installed default systemd service: #{service_name}")
            :ok
          {output, _} ->
            {:error, "Failed to install systemd service: #{output}"}
        end
      {output, _} ->
        {:error, "Failed to create service file: #{output}"}
    end
  end

  defp configure_nginx(config) do
    if File.exists?("deploy/nginx.conf") do
      # Read and update nginx config
      nginx_content = File.read!("deploy/nginx.conf")
      |> String.replace("${SERVER_NAME}", URI.parse(config.url || "").host || config.app_name)
      |> String.replace("${APP_PORT}", to_string(config.app_port))
      |> String.replace("${APP_NAME}", config.app_name)
      |> String.replace("${DEPLOY_TO}", config.deploy_to)
      
      site_name = "#{config.app_name}-phoenix"
      
      # Write nginx config
      write_cmd = """
      cat > #{config.deploy_to}/shared/#{site_name}.conf << 'EOF'
      #{nginx_content}
      EOF
      """
      
      case ssh_exec(config, write_cmd) do
        {_, 0} ->
          link_cmd = """
          sudo ln -sf #{config.deploy_to}/shared/#{site_name}.conf /etc/nginx/sites-available/#{site_name} && \
          sudo ln -sf /etc/nginx/sites-available/#{site_name} /etc/nginx/sites-enabled/#{site_name} && \
          sudo nginx -t
          """
          
          case ssh_exec(config, link_cmd) do
            {_, 0} ->
              Logger.info("Configured NGINX for: #{site_name}")
              Logger.info("Remember to reload NGINX: sudo systemctl reload nginx")
              :ok
            {output, _} ->
              {:error, "Failed to configure NGINX: #{output}"}
          end
        {output, _} ->
          {:error, "Failed to write NGINX config: #{output}"}
      end
    else
      Logger.info("No NGINX config found at deploy/nginx.conf, skipping...")
      :ok
    end
  end

  defp create_shared_files(config) do
    shared_files = Map.get(config, :shared_files, [])
    
    # Create empty shared files
    create_files_cmd = shared_files
    |> Enum.map(fn file ->
      "touch #{config.deploy_to}/shared/#{file}"
    end)
    |> Enum.join(" && ")
    
    if create_files_cmd != "" do
      case ssh_exec(config, create_files_cmd) do
        {_, 0} -> :ok
        {output, _} -> 
          Logger.warning("Failed to create some shared files: #{output}")
          :ok  # Don't fail setup
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

  defp generate_password do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end

  defp generate_secret_key_base do
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end
end