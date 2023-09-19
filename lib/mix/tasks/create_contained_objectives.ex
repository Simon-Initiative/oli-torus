defmodule Mix.Tasks.CreateContainedObjectives do
  @moduledoc "Printed when the user requests `mix help create_contained_objectives`"
  @shortdoc "Create contained objectives for all sections that were not migrated"

  use Mix.Task

  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Delivery.Sections.Section
  alias Ecto.Multi

  require Logger

  import Ecto.Query, only: [from: 2]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Logger.info("Start enqueueing contained objectives creation")

    res =
      Multi.new()
      |> Multi.run(:sections, &get_not_started_sections(&1, &2))
      |> Oban.insert_all(:jobs, &build_contained_objectives_jobs(&1))
      |> Ecto.Multi.update_all(
        :update_all_sections,
        fn _ -> from(Section, where: [v25_migration: :not_started]) end,
        set: [v25_migration: :pending]
      )
      |> Repo.transaction()

    case res do
      {:ok, %{jobs: jobs}} ->
        Logger.info("#{Enum.count(jobs)} jobs enqueued for contained objectives creation")

      {:error, _, changeset, _} ->
        Logger.error("Error enqueuing jobs: #{inspect(changeset)}")
    end
  end

  defp get_not_started_sections(_repo, _changes),
    do: {:ok, Sections.get_sections_by([v25_migration: :not_started], [:slug])}

  defp build_contained_objectives_jobs(%{sections: sections}) do
    Enum.map(
      sections,
      &Oli.Delivery.Sections.ContainedObjectivesBuilder.new(%{section_slug: &1.slug})
    )
  end
end
