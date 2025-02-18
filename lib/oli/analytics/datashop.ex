defmodule Oli.Analytics.Datashop do
  @moduledoc """
  For documentation on DataShop logging message formats, see:

  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd
  """
  import Ecto.Query

  alias Oli.Repo
  alias Oli.DatashopCache
  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Analytics.Datashop.Messages.{Context, Tool, Tutor}
  alias Oli.Analytics.Datashop.Utils
  alias Oli.Resources.{Revision, ResourceType}

  def max_record_size() do
    20_000
  end

  # Creates a map of resource ids to lists, where the lists are the
  # full paths of revisons from the root to that resource's position in the hierarchy.
  # An entry in this map for a leaf page of id 34, would look like:
  #
  # 34 => [%Revision{}, %Revision{}, %Revision{}, %Revision{}]
  #         ^                ^            ^            ^
  #       the page       a module      a unit        Root Resource
  defp build_hierarchy_map(revision_map, root_resource_id) do
    Map.get(revision_map, root_resource_id)
    |> build_hierarchy([], [], revision_map)
    |> Enum.reduce(%{}, fn [page | _] = path, m -> Map.put(m, page.resource_id, path) end)
  end

  defp build_hierarchy(%Revision{} = rev, path, acc, revision_map) do
    case ResourceType.get_type_by_id(rev.resource_type_id) do
      "page" ->
        [[rev | path] | acc]

      "container" ->
        Enum.reduce(rev.children, acc, fn c, a ->
          child_rev = Map.get(revision_map, c)
          build_hierarchy(child_rev, [rev] ++ path, [], revision_map) ++ a
        end)
    end
  end

  # safely get the hints list from a part, returning an empty list if
  # the part or the hints do not exist, or if hints is present but not a list
  defp get_hints_for_part(part_attempt) do
    case get_part_from_attempt(part_attempt) do
      nil ->
        []

      map ->
        case Map.get(map, "hints") do
          nil -> []
          hints when is_list(hints) -> hints
          _ -> []
        end
    end
  end

  defp part_attempts_stream(section_ids, offset, limit) do
    from(part_attempt in Oli.Delivery.Attempts.Core.PartAttempt,
      join: activity_attempt in Oli.Delivery.Attempts.Core.ActivityAttempt,
      on: activity_attempt.id == part_attempt.activity_attempt_id,
      join: resource_attempt in Oli.Delivery.Attempts.Core.ResourceAttempt,
      on: resource_attempt.id == activity_attempt.resource_attempt_id,
      join: resource_access in Oli.Delivery.Attempts.Core.ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      join: user in Oli.Accounts.User,
      on: resource_access.user_id == user.id,
      join: activity_revision in Oli.Resources.Revision,
      on: activity_revision.id == activity_attempt.revision_id,
      where: resource_access.section_id in ^section_ids,
      select: %{
        email: user.email,
        sub: user.sub,
        slug: activity_revision.slug,
        part_attempt: part_attempt,
        page_id: resource_access.resource_id,
        objectives: activity_revision.objectives,
        activity_type_id: activity_revision.activity_type_id
      },
      order_by: [desc: part_attempt.inserted_at],
      offset: ^offset,
      limit: ^limit
    )
    |> Repo.stream()
  end

  def count(section_ids) do
    from(part_attempt in Oli.Delivery.Attempts.Core.PartAttempt,
      join: activity_attempt in Oli.Delivery.Attempts.Core.ActivityAttempt,
      on: activity_attempt.id == part_attempt.activity_attempt_id,
      join: resource_attempt in Oli.Delivery.Attempts.Core.ResourceAttempt,
      on: resource_attempt.id == activity_attempt.resource_attempt_id,
      join: resource_access in Oli.Delivery.Attempts.Core.ResourceAccess,
      on: resource_access.id == resource_attempt.resource_access_id,
      where: resource_access.section_id in ^section_ids,
      select: count(part_attempt.id)
    )
    |> Repo.one()
  end

  def content_stream(context, offset, limit) do
    %{
      hierarchy_map: hierarchy_map,
      activity_types: activity_types,
      skill_titles: skill_titles,
      dataset_name: dataset_name,
      project: project,
      publication: publication,
      section_ids: section_ids
    } = context

    section_ids
    |> part_attempts_stream(offset, limit)
    |> Stream.map(fn %{
                       email: email,
                       sub: sub,
                       slug: activity_slug,
                       part_attempt: part_attempt
                     } ->
      activity_attempt = DatashopCache.get_activity_attempt!(part_attempt.activity_attempt_id)

      activity_revision = DatashopCache.get_revision!(activity_attempt.revision_id)

      resource_attempt = DatashopCache.get_resource_attempt!(activity_attempt.resource_attempt_id)

      page_revision = DatashopCache.get_revision!(resource_attempt.revision_id)

      resource_attempt = %{resource_attempt | revision: page_revision}
      activity_attempt = %{activity_attempt | revision: activity_revision}
      activity_attempt = %{activity_attempt | resource_attempt: resource_attempt}
      part_attempt = %{part_attempt | activity_attempt: activity_attempt}

      context = %{
        date: part_attempt.date_submitted,
        email: email,
        sub: sub,
        datashop_session_id: part_attempt.datashop_session_id,
        context_message_id: Utils.make_unique_id(activity_slug, part_attempt.part_id),
        problem_name: Utils.make_problem_name(activity_slug, part_attempt.part_id),
        transaction_id: Utils.make_unique_id(activity_slug, part_attempt.part_id),
        dataset_name: dataset_name,
        part_attempt: part_attempt,
        publication: publication,
        project: project,
        hierarchy_map: hierarchy_map,
        activity_types: activity_types,
        skill_titles: skill_titles,
        skill_ids: part_attempt.activity_attempt.revision.objectives[part_attempt.part_id] || [],
        total_hints_available: get_hints_for_part(part_attempt) |> length
      }

      context_message = Context.setup("START_PROBLEM", context)

      hint_message_pairs =
        create_hint_message_pairs(
          part_attempt,
          context
        )

      # Attempt / Result pairs must have a different transaction ID from the hint message pairs
      context =
        Map.put(
          context,
          :transaction_id,
          Utils.make_unique_id(activity_slug, part_attempt.part_id)
        )

      all =
        hint_message_pairs ++
          [
            Tool.setup("ATTEMPT", "ATTEMPT", context),
            Tutor.setup("RESULT", context)
          ]

      [context_message | all]
    end)
  end

  def build_context(project_id, section_ids) do
    project = Course.get_project!(project_id)
    publication = Publishing.get_latest_published_publication_by_slug(project.slug)

    # Fetch context information such as hierarchy revisions, skill titles and
    # registered activity slugs ahead of time and place them into the context

    # a map of resource ids to published revision
    hierarchy_map =
      Publishing.get_published_resources_by_publication(publication.id)
      |> Enum.reduce(%{}, fn pr, m -> Map.put(m, pr.resource_id, pr.revision) end)
      |> build_hierarchy_map(publication.root_resource_id)

    activity_types =
      Oli.Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.id, a) end)

    skill_titles =
      Oli.Publishing.get_published_objective_details(publication.id)
      |> Enum.reduce(%{}, fn a, m -> Map.put(m, a.resource_id, a.title) end)

    %{
      hierarchy_map: hierarchy_map,
      activity_types: activity_types,
      skill_titles: skill_titles,
      dataset_name: Utils.make_dataset_name(project.slug),
      project: project,
      publication: publication,
      section_ids: section_ids
    }
  end

  def content_prefix() do
    """
    <?xml version= \"1.0\" encoding= \"UTF-8\"?>
    <tutor_related_message_sequence version_number= \"4\" xmlns:xsi= \"http://www.w3.org/2001/XMLSchema-instance\" xsi:noNamespaceSchemaLocation= \"http://pslcdatashop.org/dtd/tutor_message_v4.xsd\">
    """
  end

  def content_suffix() do
    """
    </tutor_related_message_sequence>
    """
  end

  defp create_hint_message_pairs(
         part_attempt,
         context
       ) do
    get_hints_for_part(part_attempt)
    |> Enum.take(length(part_attempt.hints))
    |> Enum.with_index()
    |> Enum.flat_map(fn {hint_content, hint_index} ->
      context =
        Map.merge(context, %{
          # TODO: add better hint request timestamp tracking. For now, just use the part attempt inserted_at
          date: part_attempt.inserted_at,
          current_hint_number: hint_index + 1,
          hint_text: Utils.hint_text(hint_content)
        })

      [
        Tool.setup("HINT", "HINT_REQUEST", context),
        Tutor.setup("HINT_MSG", context)
      ]
    end)
  end

  defp get_part_from_attempt(part_attempt) do
    Attempts.select_model(part_attempt.activity_attempt)["authoring"]["parts"]
    |> Enum.find(%{}, &(&1["id"] == part_attempt.part_id))
  end
end
