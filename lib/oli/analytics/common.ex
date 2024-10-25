defmodule Oli.Analytics.Common do
  import Ecto.Query, warn: false

  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Revision
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{PartAttempt, ActivityAttempt}
  alias Oli.Activities
  alias OliWeb.Common.FormatDateTime
  alias Oli.Activities.ActivityRegistration

  @doc """
  Take an enumeration of maps of data and return a JSON Lines compatible string.
  """
  def to_jsonlines(maps) do
    Enum.map(maps, fn m -> Jason.encode!(m) end)
    |> Enum.join("\n")
  end

  defp get_objectives_map(project_slug) do
    resource_type_id = Oli.Resources.ResourceType.get_id_by_type("objective")

    from(m in Oli.Publishing.PublishedResource,
      join: rev in Revision,
      on: rev.id == m.revision_id,
      where:
        m.publication_id in subquery(
          Oli.Publishing.AuthoringResolver.project_working_publication(project_slug)
        ) and
          rev.resource_type_id == ^resource_type_id,
      select: %{
        resource_id: rev.resource_id,
        title: rev.title
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{resource_id: id} = o, m -> Map.put(m, id, o) end)
  end

  defp get_activities_map(project_slug) do
    resource_type_id = Oli.Resources.ResourceType.get_id_by_type("activity")

    from(m in Oli.Publishing.PublishedResource,
      join: rev in Revision,
      on: rev.id == m.revision_id,
      where:
        m.publication_id in subquery(
          Oli.Publishing.AuthoringResolver.project_working_publication(project_slug)
        ) and
          rev.resource_type_id == ^resource_type_id,
      select: %{
        title: rev.title,
        resource_id: rev.resource_id,
        activity_type_id: rev.activity_type_id,
        content: rev.content
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn %{resource_id: id} = o, m -> Map.put(m, id, o) end)
  end

  def stream_project_raw_analytics_to_file!(project_slug, append_to_filepath) do
    objectives_map = get_objectives_map(project_slug)
    activities_map = get_activities_map(project_slug)

    activity_registration_map =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn %ActivityRegistration{id: id} = registration, acc ->
        Map.put(acc, id, registration)
      end)

    sections_map =
      from(project in Project,
        join: section in Section,
        on: section.base_project_id == project.id,
        where: project.slug == ^project_slug and section.type == :enrollable,
        select: {
          section.id,
          section.title,
          section.slug
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn {section_id, title, slug}, acc ->
        Map.put(acc, section_id, %{title: title, slug: slug})
      end)

    all_section_ids = Map.keys(sections_map)

    Repo.transaction(fn ->
      Repo.stream(
        from(part_attempt in PartAttempt,
          join: activity_attempt in ActivityAttempt,
          on: part_attempt.activity_attempt_id == activity_attempt.id,
          join: resource_attempt in Oli.Delivery.Attempts.Core.ResourceAttempt,
          on: resource_attempt.id == activity_attempt.resource_attempt_id,
          join: resource_access in Oli.Delivery.Attempts.Core.ResourceAccess,
          on: resource_access.id == resource_attempt.resource_access_id,
          where: resource_access.section_id in ^all_section_ids,
          select: %{
            part_attempt_id: part_attempt.id,
            part_id: part_attempt.part_id,
            part_attempt_attempt_number: part_attempt.attempt_number,
            activity_revision_id: activity_attempt.revision_id,
            page_revision_id: resource_attempt.revision_id,
            activity_id: activity_attempt.resource_id,
            page_id: resource_access.resource_id,
            activity_attempt_number: activity_attempt.attempt_number,
            hints: part_attempt.hints,
            inserted_at: part_attempt.inserted_at,
            user_id: resource_access.user_id,
            section_id: resource_access.section_id,
            score: part_attempt.score,
            out_of: part_attempt.out_of,
            response: part_attempt.response,
            feedback: part_attempt.feedback,
            activity_attempt_id: activity_attempt.id,
            resource_attempt_id: resource_attempt.id
          }
        )
      )
      |> Stream.map(fn %{
                         part_attempt_id: part_attempt_id,
                         part_id: part_id,
                         activity_revision_id: activity_attempt_revision_id,
                         page_revision_id: resource_attempt_revision_id,
                         activity_id: activity_attempt_resource_id,
                         page_id: resource_attempt_resource_id,
                         part_attempt_attempt_number: part_attempt_attempt_number,
                         activity_attempt_id: activity_attempt_id,
                         resource_attempt_id: resource_attempt_id,
                         hints: hints,
                         inserted_at: inserted_at,
                         user_id: user_id,
                         section_id: section_id,
                         score: score,
                         out_of: out_of,
                         response: response,
                         feedback: feedback
                       } ->
        activity = Map.get(activities_map, activity_attempt_resource_id)
        activity_registration = Map.get(activity_registration_map, activity.activity_type_id)
        section = Map.get(sections_map, section_id)

        activity_revision = Oli.DatashopCache.get_revision!(activity_attempt_revision_id)
        page_revision = Oli.DatashopCache.get_revision!(resource_attempt_revision_id)

        objectives =
          Map.get(activity_revision, :objectives, %{} |> Map.put(part_id, []))
          |> Map.get(part_id, [])
          |> Enum.dedup()
          |> Enum.map(fn id ->
            case Map.get(objectives_map, id) do
              nil -> %{resource_id: id, title: "Unknown"}
              item -> item
            end
          end)

        [
          [
            part_attempt_id,
            part_id,
            activity_attempt_resource_id,
            resource_attempt_resource_id,
            activity.title,
            activity_registration.title,
            part_attempt_attempt_number,
            page_revision.graded,
            if score == out_of do
              true
            else
              false
            end,
            score,
            out_of,
            hints,
            Jason.encode_to_iodata!(response),
            Jason.encode_to_iodata!(feedback),
            Jason.encode_to_iodata!(activity.content),
            Jason.encode_to_iodata!(%{objectives: objectives}),
            section.title,
            section.slug,
            FormatDateTime.date(inserted_at),
            user_id,
            activity_attempt_id,
            resource_attempt_id
          ]
        ]
        |> CSV.encode(separator: ?\t)
        |> Enum.map(&File.write!(append_to_filepath, &1, [:append]))
      end)
      |> Stream.run()
    end)
  end
end
