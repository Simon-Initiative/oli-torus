defmodule Oli.Analytics.Datashop do
  @moduledoc """
  For documentation on DataShop logging message formats, see:

  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd
  """

  import XmlBuilder
  import Oli.Utils, only: [value_or: 2]

  alias Oli.Publishing
  alias Oli.Authoring.Course
  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Analytics.Datashop.Messages.{Context, Tool, Tutor}
  alias Oli.Analytics.Datashop.Utils
  alias Oli.Resources.{Revision, ResourceType}

  def export(project_id) do
    project_id
    |> create_messages
    |> wrap_with_tutor_related_message
    |> document
    |> generate
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

  defp create_messages(project_id) do
    project = Course.get_project!(project_id)
    publication = Publishing.get_latest_published_publication_by_slug(project.slug)
    dataset_name = Utils.make_dataset_name(project.slug)

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

    Attempts.get_part_attempts_and_users(project.id)
    |> group_part_attempts_by_user_and_part
    |> Enum.map(fn {{email, sub, activity_slug, part_id}, part_attempts} ->
      context = %{
        date: hd(part_attempts).activity_attempt.resource_attempt.inserted_at,
        email: email,
        sub: sub,
        # datashop_session_id will be set to the latest part attempt datashop_session_id
        # unless it is nil, then it will be set to a generated UUID. This will handle any
        # part attempts that existed before this value was tracked in the part attempt record
        datashop_session_id: value_or(hd(part_attempts).datashop_session_id, UUID.uuid4()),
        context_message_id: Utils.make_unique_id(activity_slug, part_id),
        problem_name: Utils.make_problem_name(activity_slug, part_id),
        dataset_name: dataset_name,
        part_attempt: hd(part_attempts),
        records: part_attempts,
        publication: publication,
        project: project,
        hierarchy_map: hierarchy_map,
        activity_types: activity_types,
        skill_titles: skill_titles
      }

      [
        Context.setup("START_PROBLEM", context)
        | part_attempts
          |> Enum.flat_map(fn part_attempt ->
            context =
              Map.merge(
                context,
                %{
                  date: part_attempt.date_submitted,
                  transaction_id: Utils.make_unique_id(activity_slug, part_id),
                  part_attempt: part_attempt,
                  skill_ids:
                    part_attempt.activity_attempt.revision.objectives[part_attempt.part_id] || [],
                  total_hints_available: get_hints_for_part(part_attempt) |> length
                }
              )

            hint_message_pairs =
              create_hint_message_pairs(
                part_attempt,
                context
              )

            # Attempt / Result pairs must have a different transaction ID from the hint message pairs
            context =
              Map.put(context, :transaction_id, Utils.make_unique_id(activity_slug, part_id))

            hint_message_pairs ++
              [
                Tool.setup("ATTEMPT", "ATTEMPT", context),
                Tutor.setup("RESULT", context)
              ]
          end)
      ]
    end)
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

  defp group_part_attempts_by_user_and_part(part_attempts_and_users) do
    Enum.reduce(part_attempts_and_users, %{}, fn r, m ->
      key = safely_build_key(r)

      case Map.get(m, key) do
        nil -> Map.put(m, key, [r.part_attempt])
        records -> Map.put(m, key, [r.part_attempt | records])
      end
    end)
    |> Enum.reduce(%{}, fn {k, v}, m -> Map.put(m, k, Enum.reverse(v)) end)
    |> Enum.map(fn {k, v} -> {k, v} end)
  end

  defp safely_build_key(r) do
    [
      r.user.email,
      r.user.sub,
      r.part_attempt.activity_attempt.revision.slug,
      r.part_attempt.part_id
    ]
    |> Enum.map(fn k ->
      if is_nil(k) do
        ""
      else
        k
      end
    end)
    |> List.to_tuple()
  end

  # Wraps the messages inside a <tutor_related_message_sequence />, which is required by the
  # Datashop DTD to set the meta-info.
  defp wrap_with_tutor_related_message(children) do
    element(
      :tutor_related_message_sequence,
      %{
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:noNamespaceSchemaLocation" => "http://pslcdatashop.org/dtd/tutor_message_v4.xsd",
        "version_number" => "4"
      },
      children
    )
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
