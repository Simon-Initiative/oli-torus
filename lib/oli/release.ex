defmodule Oli.ReleaseTasks do
  @app :oli

  def reset() do
    drop()
    create()
    migrate()
    seed()
  end

  def setup() do
    create()
    migrate()
    seed()
  end

  def drop do
    IO.puts "WARNING! This will completely erase all data from the database."
    confirm = IO.gets "Are you sure you want to continue? (Enter YES to continue): "

    if String.upcase(confirm) == "YES\n" do
      load_app()

      for repo <- repos() do
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, all: true))
      end

      IO.puts "database repos dropped."
    else
      IO.puts "drop operation cancelled by user."
      :init.stop()
    end
  end

  def create do
    load_app()

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end

    IO.puts "database repos created."
  end

  defp ensure_repo_created(repo) do
    IO.puts "create #{inspect repo} database if it doesn't exist"
    case repo.__adapter__.storage_up(repo.config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, term} -> {:error, term}
    end
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def seed do
    load_app()
    start_repos()

    # Run the seed script if it exists
    seed_script = seed_path(:oli)
    if File.exists?(seed_script) do
      IO.puts "Running seed script.."
      Code.eval_file(seed_script)

      IO.puts "seed complete."
    else
      IO.puts :stderr, "seed script does not exist."
    end

  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  # defp start_deps(apps) do
  #   IO.puts "Starting dependencies.."
  #   # Start apps necessary for executing migrations
  #   Enum.each(apps, &Application.ensure_all_started/1)
  # end

  defp start_repos() do
    # Start the Repo(s) for app
    IO.puts "Starting repos.."
    Enum.each(repos(), &(&1.start_link(pool_size: 1)))
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"
  # defp migrations_path(app), do: Path.join([priv_dir(app), "repo", "migrations"])
  defp seed_path(app), do: Path.join([priv_dir(app), "repo", "seeds.exs"])

end
