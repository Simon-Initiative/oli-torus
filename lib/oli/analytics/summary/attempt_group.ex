defmodule Oli.Analytics.Summary.AttemptGroup do
  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Analytics.XAPI.Events.Context

  @moduledoc """
  Represents a collection of evaluated part attempts, and the possible activity and page
  attempts that they evaluted into (as part of either complete activity evaluation or complete
  page evaluation).  This is the core data structure that is used to generate all summary analytics
  and related xAPI statements.  It provides not only the information regarding these attempts, but also
  the context information (user, section, project, etc.) that is needed to process the analytics
  and generate the xAPI statements.
  """

  @enforce_keys [
    :part_attempts,
    :activity_attempts,
    :resource_attempt,
    :context
  ]

  defstruct [
    :part_attempts,
    :activity_attempts,
    :resource_attempt,
    :context
  ]

  def from_attempt_summary(
        %Oli.Analytics.Common.Pipeline{} = pipeline,
        attempt_summary,
        project_id,
        host_name
      ) do
    Map.put(pipeline, :data, from_attempt_summary(attempt_summary, project_id, host_name))
    |> Oli.Analytics.Common.Pipeline.step_done(:query)
  end

  @doc """
  For a collection of part attempt guids,
  gather a evaluated attempt group, which is all the information needed in order
  to both emit an xAPI statement for each part attempt, and to process all summary analytics.
  """
  def from_attempt_summary([], _project_id, _host_name), do: nil

  def from_attempt_summary(attempt_summary, project_id, host_name) do
    {_, _, ra, resource_access, _} = List.first(attempt_summary)

    part_attempts =
      Enum.map(attempt_summary, fn {pa, aa, _, _, ar} ->
        Map.merge(pa, %{
          activity_attempt: aa,
          activity_revision: ar
        })
      end)

    activity_attempts =
      Enum.map(attempt_summary, fn {_, aa, _, _, _} -> aa end)
      |> Enum.filter(fn activity_attempt -> activity_attempt.lifecycle_state == :evaluated end)
      |> Enum.dedup()

    resource_attempt = Map.merge(ra, %{resource_id: resource_access.resource_id})

    context = build_context(attempt_summary, project_id, host_name)

    %__MODULE__{
      context: context,
      part_attempts: part_attempts,
      activity_attempts: activity_attempts,
      resource_attempt: resource_attempt
    }
  end

  defp build_context([{_, _, _, access, _} | _rest], project_id, host_name) do
    {enrollment_id, publication_id} =
      enrollment_publication_ids_for_section_user_project(
        access.section_id,
        access.user_id,
        project_id
      )

    %Context{
      host_name: host_name,
      user_id: access.user_id,
      section_id: access.section_id,
      enrollment_id: enrollment_id,
      project_id: project_id,
      publication_id: publication_id
    }
  end

  defp enrollment_publication_ids_for_section_user_project(section_id, user_id, nil) do
    query =
      from s in Oli.Delivery.Sections.Section,
        where: s.id == ^section_id,
        select: {
          fragment(
            "(SELECT id FROM enrollments WHERE section_id = ? AND user_id = ? LIMIT 1)",
            ^section_id,
            ^user_id
          ),
          fragment(
            "(SELECT publication_id FROM sections_projects_publications WHERE section_id = ? ORDER BY publication_id DESC LIMIT 1)",
            ^section_id
          )
        }

    Repo.one(query) || {nil, nil}
  end

  defp enrollment_publication_ids_for_section_user_project(section_id, user_id, project_id) do
    query =
      from s in Oli.Delivery.Sections.Section,
        where: s.id == ^section_id,
        select: {
          fragment(
            "(SELECT id FROM enrollments WHERE section_id = ? AND user_id = ? LIMIT 1)",
            ^section_id,
            ^user_id
          ),
          fragment(
            "(SELECT publication_id FROM sections_projects_publications WHERE section_id = ? AND project_id = ? LIMIT 1)",
            ^section_id,
            ^project_id
          )
        }

    Repo.one(query) || {nil, nil}
  end
end
