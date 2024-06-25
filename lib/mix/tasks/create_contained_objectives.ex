defmodule Mix.Tasks.CreateContainedObjectives do
  @shortdoc """
  Create contained objectives for all sections that have not yet been migrated.
  Use --all to drop existing objectives and create contained objectives for all sections.
  """

  use Mix.Task

  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Delivery.Sections.{ContainedObjectivesBuilder, Section}
  alias Ecto.Multi

  require Logger

  import Ecto.Query, only: [from: 2]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    run_now(args)
  end

  def run_now(args) do
    Logger.info("Start enqueueing contained objectives creation")

    opts = build_opts(args)

    Multi.new()
    |> Multi.run(:sections, &get_selected_sections(&1, &2, opts))
    |> Oban.insert_all(:jobs, &build_contained_objectives_jobs(&1))
    |> Ecto.Multi.update_all(
      :update_all_sections,
      fn _ ->
        sections_filter = opts[:all] || [v25_migration: :not_started]
        from(Section, where: ^sections_filter)
      end,
      set: [v25_migration: :pending]
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{jobs: jobs}} ->
        Logger.info("#{Enum.count(jobs)} jobs enqueued for contained objectives creation")

        :ok

      {:error, _, changeset, _} ->
        Logger.error("Error enqueuing jobs: #{inspect(changeset)}")

        :error
    end
  end

  defp get_selected_sections(_repo, _changes, all: true),
    do: {:ok, Sections.get_sections_by(true, [:slug])}

  defp get_selected_sections(_repo, _changes, _opts),
    do: {:ok, Sections.get_sections_by([v25_migration: :not_started], [:slug])}

  defp build_contained_objectives_jobs(%{sections: sections}),
    do: Enum.map(sections, &ContainedObjectivesBuilder.new(%{section_slug: &1.slug}))

  defp build_opts(args) do
    if "--all" in args do
      [all: true]
    else
      []
    end
  end
end
