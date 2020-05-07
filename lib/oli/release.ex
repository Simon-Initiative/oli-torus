defmodule Oli.Release do
  @app :oli

  def create_and_migrate() do
    createdb()
    migrate()
  end

  def createdb do
    # Start postgrex and ecto
    IO.puts "Starting dependencies..."

    # Start apps necessary for executing migrations
    Enum.each([@app, :postgrex, :ecto, :ecto_sql], &Application.ensure_all_started/1)

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end

    IO.puts "createdb complete!"
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

    IO.puts "migrate complete!"
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
end
