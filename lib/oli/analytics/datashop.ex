defmodule Oli.Analytics.Datashop do
  @moduledoc """
  For documentation on DataShop logging message formats, see:

  https://pslcdatashop.web.cmu.edu/dtd/guide/tutor_message_dtd_guide_v4.pdf
  https://pslcdatashop.web.cmu.edu/help?page=logging
  https://pslcdatashop.web.cmu.edu/help?page=importFormatTd
  """

  import XmlBuilder
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

    Attempts.get_part_attempts_and_users(project.id)
    |> group_part_attempts_by_user_and_part
    |> Enum.map(fn {{email, sub, activity_slug, part_id}, part_attempts} ->
      context = %{
        date: hd(part_attempts).activity_attempt.resource_attempt.inserted_at,
        email: email,
        sub: sub,
        context_message_id: Utils.make_unique_id(activity_slug, part_id),
        problem_name: Utils.make_problem_name(activity_slug, part_id),
        dataset_name: dataset_name,
        part_attempt: hd(part_attempts),
        publication: publication,
        # a map of resource ids to published revision
        hierarchy_map:
          Publishing.get_published_resources_by_publication(publication.id)
          |> Enum.reduce(%{}, fn pr, m -> Map.put(m, pr.resource_id, pr.revision) end)
          |> build_hierarchy_map(publication.root_resource_id)
      }

      [
        Context.setup("START_PROBLEM", context)
        | part_attempts
          |> Enum.flat_map(fn part_attempt ->
            context =
              Map.merge(
                context,
                %{
                  transaction_id: Utils.make_unique_id(activity_slug, part_id),
                  part_attempt: part_attempt,
                  skill_ids:
                    part_attempt.activity_attempt.revision.objectives[part_attempt.part_id] || [],
                  total_hints_available:
                    Utils.total_hints_available(get_part_from_attempt(part_attempt))
                }
              )

            hint_message_pairs =
              create_hint_message_pairs(
                part_attempt,
                get_part_from_attempt(part_attempt),
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

  defp group_part_attempts_by_user_and_part(part_attempts_and_users) do
    part_attempts_and_users
    |> Enum.group_by(
      &{&1.user.email, &1.user.sub, &1.part_attempt.activity_attempt.revision.slug,
       &1.part_attempt.part_id},
      & &1.part_attempt
    )
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

  defp create_hint_message_pairs(part_attempt, part, context) do
    part_attempt.hints
    |> Enum.with_index()
    |> Enum.flat_map(fn {hint_id, hint_index} ->
      context =
        Map.merge(context, %{
          current_hint_number: hint_index + 1,
          hint_text: Utils.hint_text(part, hint_id)
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
