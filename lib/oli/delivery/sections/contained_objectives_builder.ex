defmodule Oli.Delivery.Sections.ContainedObjectivesBuilder do
  use Oban.Worker,
    queue: :objectives,
    unique: [keys: [:section_slug]],
    max_attempts: 1

  import Ecto.Query, only: [from: 2]

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections.{ContainedObjective, ContainedPage, Section}
  alias Oli.Delivery.Sections
  alias Oli.Resources.{Revision, ResourceType}
  alias Oli.Repo
  alias Ecto.Multi

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"section_slug" => section_slug}}) do
    timestamps = %{
      inserted_at: {:placeholder, :now},
      updated_at: {:placeholder, :now}
    }

    placeholders = %{
      now: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    Multi.new()
    |> Multi.run(
      :contained_objectives,
      &Sections.build_contained_objectives(&1, &2, section_slug)
    )
    |> Multi.insert_all(
      :inserted_contained_objectives,
      ContainedObjective,
      &objectives_with_timestamps(&1, timestamps),
      placeholders: placeholders
    )
    |> Multi.run(:section, &find_section_by_slug(&1, &2, section_slug))
    |> Multi.update(
      :done_section,
      &Section.changeset(&1.section, %{v25_migration: :done})
    )
    |> Repo.transaction()
    |> case do
      {:ok, res} ->
        {:ok, res}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  defp objectives_with_timestamps(%{contained_objectives: contained_objectives}, timestamps) do
    Enum.map(contained_objectives, &Map.merge(&1, timestamps))
  end

  defp find_section_by_slug(repo, _changes, section_slug) do
    case repo.get_by(Section, slug: section_slug) do
      nil ->
        {:error, :section_not_found}

      section ->
        {:ok, section}
    end
  end
end
