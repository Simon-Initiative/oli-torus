defmodule Oli.ReleaseTasks do
  @app :oli

  def reset() do
    drop()
    create()
    migrate()
    seed()
  end

  def reset(%{ force: true }) do
    drop(%{ force: true })
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
      drop(%{ force: true })
    else
      IO.puts "drop operation cancelled by user."
      :init.stop()
    end
  end

  def drop(%{ force: true }) do
    load_app()

    for repo <- repos() do
      drop_database(repo)
    end
  end

  defp drop_database(repo) do
    case repo.__adapter__.storage_down(repo.config) do
      :ok ->
        IO.puts "The database for #{inspect repo} has been dropped"
      {:error, :already_down} ->
        IO.puts "The database for #{inspect repo} has already been dropped"
      {:error, term} when is_binary(term) ->
        IO.puts :stderr, "The database for #{inspect repo} couldn't be dropped: #{term}"
      {:error, term} ->
        IO.puts :stderr, "The database for #{inspect repo} couldn't be dropped: #{inspect term}"
    end
  end

  def create do
    load_app()

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end
  end

  defp ensure_repo_created(repo) do
    case repo.__adapter__.storage_up(repo.config) do
      :ok ->
        IO.puts "The database for #{inspect repo} has been created"
        :ok
      {:error, :already_up} ->
        IO.puts "The database for #{inspect repo} already exists"
        :ok
      {:error, term} ->
        IO.puts :stderr, "The database for #{inspect repo} couldn't be created: #{term}"
        {:error, term}
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

  defp start_repos() do
    # Start the Repo(s) for app
    IO.puts "Starting repos.."
    Enum.each(repos(), &(&1.start_link(pool_size: 1)))
  end

  defp priv_dir(app), do: "#{:code.priv_dir(app)}"
  defp seed_path(app), do: Path.join([priv_dir(app), "repo", "seeds.exs"])

end
