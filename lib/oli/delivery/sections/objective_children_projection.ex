defmodule Oli.Delivery.Sections.ObjectiveChildrenProjection do
  @moduledoc """
  Projects pinned objective Revision children onto SectionResources.

  Revision children are resource IDs; SectionResource children are SectionResource
  IDs. The projection is rebuilt from a Section's pinned project publications so
  initial creation, remix rebuilds, and JIT migration share the same mapping.
  """

  import Ecto.Query

  alias Oli.Delivery.Sections.{SectionResource, SectionsProjectsPublications}
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.{ResourceType, Revision}

  @objective_type_id ResourceType.id_for_objective()

  @spec persist(integer()) :: {:ok, non_neg_integer()} | {:error, term()}
  def persist(section_id) do
    updates = calculate(section_id)

    case updates do
      [] ->
        {:ok, 0}

      updates ->
        payload = Enum.map(updates, &%{"id" => &1.id, "children" => &1.children})

        sql = """
        UPDATE section_resources AS sr
        SET children = projected.children,
            updated_at = NOW()
        FROM jsonb_to_recordset($1::jsonb)
          AS projected(id bigint, children bigint[])
        WHERE sr.id = projected.id
        """

        case Repo.query(sql, [payload]) do
          {:ok, %{num_rows: count}} -> {:ok, count}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp calculate(section_id) do
    objectives =
      from(sr in SectionResource,
        left_join: spp in SectionsProjectsPublications,
        on: spp.section_id == sr.section_id and spp.project_id == sr.project_id,
        left_join: pr in PublishedResource,
        on:
          pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id and
            pr.revision_id == sr.revision_id,
        left_join: revision in Revision,
        on:
          revision.id == pr.revision_id and revision.id == sr.revision_id and
            revision.resource_id == pr.resource_id and revision.deleted == false,
        where: sr.section_id == ^section_id and sr.resource_type_id == ^@objective_type_id,
        select: %{
          id: sr.id,
          resource_id: sr.resource_id,
          resolved_revision_id: revision.id,
          child_resource_ids: revision.children
        }
      )
      |> Repo.all()

    section_resource_id_by_resource_id =
      objectives
      |> Enum.reject(&is_nil(&1.resolved_revision_id))
      |> Map.new(&{&1.resource_id, &1.id})

    Enum.map(objectives, fn objective ->
      children =
        objective.child_resource_ids
        |> List.wrap()
        |> Enum.map(&Map.get(section_resource_id_by_resource_id, &1))
        |> Enum.reject(&is_nil/1)

      %{id: objective.id, children: children}
    end)
  end
end
