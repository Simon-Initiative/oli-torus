defmodule Oli.Analytics.Summary.AttemptGroup do

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Analytics.Summary.Context

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

  def from_attempt_summary(%Oli.Analytics.Summary.Pipeline{} = pipeline, attempt_summary, project_id, host_name) do
    Map.put(pipeline, :attempt_group, from_attempt_summary(attempt_summary, project_id, host_name))
  end

  @doc """
  For a collection of part attempt guids,
  gather a evaluated attempt group, which is all the information needed in order
  to both emit an xAPI statement for each part attempt, and to process all summary analytics.
  """
  def from_attempt_summary(attempt_summary, project_id, host_name) do

    part_attempts = Enum.map(attempt_summary, fn {pa, aa, _, _, _, ar} ->
      Map.merge(pa, %{
        activity_attempt: aa,
        activity_revision: ar
      })
    end)

    activity_attempts = Enum.map(attempt_summary, fn {_, aa, _, _, _, _} -> aa end)
    |> Enum.filter(fn activity_attempt -> activity_attempt.lifecycle_state == :evaluated end)
    |> Enum.dedup()

    {_, _, ra, _, page_revision, _} = List.first(attempt_summary)
    resource_attempt = Map.merge(ra, %{resource_id: page_revision.resource_id})

    context = build_context(attempt_summary, project_id, host_name)

    %__MODULE__{
      context: context,
      part_attempts: part_attempts,
      activity_attempts: activity_attempts,
      resource_attempt: resource_attempt
    }

  end

  defp build_context([{_, _, _, access, _, _} | _rest], project_id, host_name) do
    %Context{
      host_name: host_name,
      user_id: access.user_id,
      section_id: access.section_id,
      project_id: project_id,
      publication_id: project_id_for_section_project(access.section_id, project_id)
    }
  end

  defp project_id_for_section_project(section_id, project_id) do
    query = from spp in Oli.Delivery.Sections.SectionsProjectsPublications,
      where: spp.section_id == ^section_id and spp.project_id == ^project_id,
      select: spp.publication_id

    Repo.one(query)
  end

end
