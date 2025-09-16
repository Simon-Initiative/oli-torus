defmodule Oli.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :oli

  def reset() do
    drop()
    create()
    migrate()
    seed()
  end

  def reset(%{dangerously_force: true}) do
    drop(%{dangerously_force: true})
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
    IO.puts("WARNING! This will completely erase all data from the database.")
    IO.puts("THIS IS A DANGEROUS AND PERMANENT OPERATION WHICH WILL RESULT IN DATA LOSS")
    confirm = IO.gets("Are you sure you want to continue? (Enter YES to continue): ")

    if String.upcase(confirm) == "YES\n" do
      drop(%{dangerously_force: true})
    else
      IO.puts("ABORTED: Operation was not confirmed by user.")
      :init.stop()
    end
  end

  def drop(%{dangerously_force: true}) do
    load_app()

    for repo <- repos() do
      drop_database(repo)
    end
  end

  defp drop_database(repo) do
    case repo.__adapter__.storage_down(repo.config) do
      :ok ->
        IO.puts("The database for #{inspect(repo)} has been dropped")

      {:error, :already_down} ->
        IO.puts("The database for #{inspect(repo)} has already been dropped")

      {:error, term} when is_binary(term) ->
        IO.puts(:stderr, "The database for #{inspect(repo)} couldn't be dropped: #{term}")

      {:error, term} ->
        IO.puts(
          :stderr,
          "The database for #{inspect(repo)} couldn't be dropped: #{inspect(term)}"
        )
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
        IO.puts("The database for #{inspect(repo)} has been created")
        :ok

      {:error, :already_up} ->
        IO.puts("The database for #{inspect(repo)} already exists")
        :ok

      {:error, term} ->
        IO.puts(:stderr, "The database for #{inspect(repo)} couldn't be created: #{term}")
        {:error, term}
    end
  end

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    IO.puts("migrate complete.")
  end

  def seed do
    # Initialize Vault before seeds to ensure Cloak.Ecto can encrypt fields
    Oli.Vault.start_link()
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &eval_seed(&1, "seeds.exs"))
    end

    IO.puts("seed complete.")
  end

  def migrate_and_seed do
    migrate()
    seed()
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  @spec load_app() :: :ok | {:error, term()}
  defp load_app do
    Application.load(@app)
    Application.load(:lti_1p3)
  end

  @spec eval_seed(Ecto.Repo.t(), String.t()) :: any()
  defp eval_seed(repo, filename) do
    # if in the future more seed files are added, replace "" with
    # the subdirectory name containing seed files
    seeds_file = get_path(repo, "", filename)

    if File.regular?(seeds_file) do
      {:ok, Code.eval_file(seeds_file)}
    else
      {:error, "Seed file '#{seeds_file}' not found."}
    end
  end

  @spec get_path(Ecto.Repo.t(), String.t(), String.t()) :: String.t()
  defp get_path(repo, directory, filename) do
    priv_dir = "#{:code.priv_dir(@app)}"

    repo_underscore =
      repo
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    Path.join([priv_dir, repo_underscore, directory, filename])
  end
end
