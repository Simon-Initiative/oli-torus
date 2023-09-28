defmodule Oli.Delivery.Sections.ContainedObjectivesBuilder do
  use Oban.Worker,
    queue: :objectives,
    unique: [keys: [:section_slug]],
    max_attempts: 1

  import Ecto.Query, only: [from: 2]

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections.{ContainedObjective, ContainedPage, Section}
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
    |> Multi.run(:contained_objectives, &build_contained_objectives(&1, &2, section_slug))
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

  defp build_contained_objectives(repo, _changes, section_slug) do
    page_type_id = ResourceType.get_id_by_type("page")
    activity_type_id = ResourceType.get_id_by_type("activity")

    section_resource_pages =
      from(
        [sr: sr, rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
        where: not rev.deleted and rev.resource_type_id == ^page_type_id
      )

    section_resource_activities =
      from(
        [sr: sr, rev: rev, s: s] in DeliveryResolver.section_resource_revisions(section_slug),
        where: not rev.deleted and rev.resource_type_id == ^activity_type_id,
        select: rev
      )

    activity_references =
      from(
        rev in Revision,
        join: content_elem in fragment("jsonb_array_elements(?->'model')", rev.content),
        select: %{
          revision_id: rev.id,
          activity_id: fragment("(?->>'activity_id')::integer", content_elem)
        },
        where: fragment("?->>'type'", content_elem) == "activity-reference"
      )

    activity_objectives =
      from(
        rev in Revision,
        join: obj in fragment("jsonb_each_text(?)", rev.objectives),
        select: %{
          objective_revision_id: rev.id,
          objective_resource_id:
            fragment("jsonb_array_elements_text(?::jsonb)::integer", obj.value)
        },
        where: rev.deleted == false and rev.resource_type_id == ^activity_type_id
      )

    contained_objectives =
      from(
        [sr: sr, rev: rev, s: s] in section_resource_pages,
        join: cp in ContainedPage,
        on: cp.page_id == rev.resource_id and cp.section_id == s.id,
        join: ar in subquery(activity_references),
        on: ar.revision_id == rev.id,
        join: act in subquery(section_resource_activities),
        on: act.resource_id == ar.activity_id,
        join: ao in subquery(activity_objectives),
        on: ao.objective_revision_id == act.id,
        group_by: [cp.section_id, cp.container_id, ao.objective_resource_id],
        select: %{
          section_id: cp.section_id,
          container_id: cp.container_id,
          objective_id: ao.objective_resource_id
        }
      )
      |> repo.all()

    {:ok, contained_objectives}
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
