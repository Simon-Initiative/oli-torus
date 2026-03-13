defmodule Oli.Conversation.AdaptivePageContextBuilder do
  @moduledoc false

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, PartAttempt, ResourceAttempt}
  alias Oli.GenAI.AdaptiveContextTelemetry
  alias Oli.Rendering.{Content, Context}
  alias Oli.Repo
  alias Oli.Resources.PageContent
  alias Oli.Resources.Revision

  @type error_reason ::
          :activity_attempt_not_found
          | :resource_attempt_not_found
          | :no_access
          | :not_adaptive_page
          | :malformed_adaptive_page
          | :current_screen_not_found
          | :invalid_arguments

  @spec build(String.t(), integer(), integer()) :: {:ok, String.t()} | {:error, error_reason()}
  def build(activity_attempt_guid, section_id, user_id) do
    started_at = System.monotonic_time()

    case do_build(activity_attempt_guid, section_id, user_id) do
      {:ok, markdown, metadata} ->
        AdaptiveContextTelemetry.build_succeeded(duration_ms(started_at), metadata)
        {:ok, markdown}

      {:error, reason, metadata} ->
        AdaptiveContextTelemetry.build_failed(
          duration_ms(started_at),
          Map.put(metadata, :reason, reason)
        )

        {:error, reason}
    end
  end

  defp do_build(activity_attempt_guid, section_id, user_id)
       when is_binary(activity_attempt_guid) and is_integer(section_id) and is_integer(user_id) do
    with {:ok, current_attempt} <- fetch_current_attempt(activity_attempt_guid),
         {:ok, resource_attempt} <- fetch_resource_attempt(current_attempt) do
      build_for_resource_attempt(resource_attempt, activity_attempt_guid, section_id, user_id)
    else
      {:error, reason} -> {:error, reason, %{section_id: section_id}}
    end
  end

  defp do_build(_, _, _), do: {:error, :invalid_arguments, %{}}

  defp build_for_resource_attempt(resource_attempt, activity_attempt_guid, section_id, user_id) do
    metadata = %{
      section_id: section_id,
      resource_attempt_id: resource_attempt.id,
      page_revision_id: resource_attempt.revision_id
    }

    with :ok <- verify_access(resource_attempt, section_id, user_id),
         :ok <- verify_adaptive_page(resource_attempt.revision),
         {:ok, sequence_entries} <- extract_sequence_entries(resource_attempt.revision),
         {:ok, screen_visits, current_visit} <-
           build_screen_visits(resource_attempt.id, sequence_entries, activity_attempt_guid) do
      extrinsic_state = Core.fetch_extrinsic_state(resource_attempt)
      visited_sequence_ids = visited_sequence_ids(extrinsic_state, screen_visits)

      {:ok, render_markdown(current_visit, screen_visits, sequence_entries, visited_sequence_ids),
       Map.merge(metadata, %{
         visited_screen_count: length(screen_visits),
         unvisited_screen_count: count_unvisited_screens(sequence_entries, visited_sequence_ids)
       })}
    else
      {:error, reason} -> {:error, reason, metadata}
    end
  end

  defp fetch_current_attempt(activity_attempt_guid) do
    case Core.get_activity_attempt_by(attempt_guid: activity_attempt_guid) do
      %ActivityAttempt{} = activity_attempt -> {:ok, activity_attempt}
      _ -> {:error, :activity_attempt_not_found}
    end
  end

  defp fetch_resource_attempt(%ActivityAttempt{resource_attempt_id: resource_attempt_id}) do
    case Core.get_resource_attempt_and_revision(resource_attempt_id) do
      %ResourceAttempt{} = resource_attempt ->
        {:ok, Repo.preload(resource_attempt, :resource_access)}

      _ ->
        {:error, :resource_attempt_not_found}
    end
  end

  defp verify_access(%ResourceAttempt{resource_access: resource_access}, section_id, user_id) do
    case resource_access do
      %{section_id: ^section_id, user_id: ^user_id} -> :ok
      _ -> {:error, :no_access}
    end
  end

  defp verify_adaptive_page(%Revision{content: %{"advancedDelivery" => true}}), do: :ok
  defp verify_adaptive_page(_), do: {:error, :not_adaptive_page}

  defp extract_sequence_entries(%Revision{content: content}) do
    content
    |> PageContent.flat_filter(fn item -> Map.get(item, "type") == "activity-reference" end)
    |> Enum.with_index(1)
    |> Enum.map(fn {item, index} -> sequence_entry_from_node(item, index) end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> {:error, :malformed_adaptive_page}
      entries -> {:ok, entries}
    end
  end

  defp sequence_entry_from_node(item, index) do
    activity_resource_id = Map.get(item, "activity_id") || Map.get(item, "resourceId")

    case activity_resource_id do
      nil ->
        nil

      _ ->
        custom = Map.get(item, "custom", %{})

        %{
          activity_resource_id: activity_resource_id,
          position: index,
          sequence_id: Map.get(custom, "sequenceId", "screen-#{index}"),
          sequence_name: sequence_name(Map.get(custom, "sequenceName"), index)
        }
    end
  end

  defp sequence_name(name, _index) when is_binary(name) and name != "", do: name
  defp sequence_name(_, index), do: "Screen #{index}"

  defp build_screen_visits(resource_attempt_id, sequence_entries, current_attempt_guid) do
    sequence_by_resource_id = Map.new(sequence_entries, &{&1.activity_resource_id, &1})

    screen_visits =
      resource_attempt_id
      |> Core.get_ordered_activity_attempts()
      |> Enum.map(&screen_visit(&1, sequence_by_resource_id))
      |> Enum.reject(&is_nil/1)

    case Enum.find(screen_visits, &(&1.activity_attempt_guid == current_attempt_guid)) do
      nil -> {:error, :current_screen_not_found}
      current_visit -> {:ok, screen_visits, current_visit}
    end
  end

  defp screen_visit(activity_attempt, sequence_by_resource_id) do
    case Map.get(sequence_by_resource_id, activity_attempt.resource_id) do
      nil ->
        nil

      sequence_entry ->
        %{
          activity_attempt_guid: activity_attempt.attempt_guid,
          content: screen_content(activity_attempt),
          responses: response_state(activity_attempt),
          sequence_id: sequence_entry.sequence_id,
          sequence_name: resolve_sequence_name(sequence_entry, activity_attempt)
        }
    end
  end

  defp resolve_sequence_name(sequence_entry, activity_attempt) do
    case sequence_entry.sequence_name do
      nil when is_binary(activity_attempt.revision.title) ->
        activity_attempt.revision.title

      nil ->
        "Screen #{sequence_entry.position}"

      name ->
        name
    end
  end

  defp screen_content(%ActivityAttempt{revision: %Revision{} = revision}) do
    revision.content
    |> collect_text_fragments()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
    |> Enum.join("\n")
    |> case do
      "" -> "No screen content available."
      text -> text
    end
  end

  defp collect_text_fragments(value) when is_list(value) do
    Enum.flat_map(value, &collect_text_fragments/1)
  end

  defp collect_text_fragments(%{"text" => text}) when is_binary(text), do: [text]

  defp collect_text_fragments(%{} = value) do
    Enum.flat_map(value, fn
      {key, nodes} when key in ["content", "children"] and is_list(nodes) ->
        case renderable_content_list?(nodes) do
          true -> [render_nodes(nodes)]
          false -> collect_text_fragments(nodes)
        end

      {key, items} when key in ["partsLayout", "children"] and is_list(items) ->
        collect_text_fragments(items)

      {key, text}
      when key in ["prompt", "label", "placeholder", "hint", "title", "caption"] and
             is_binary(text) ->
        [text]

      {_key, nested} when is_list(nested) or is_map(nested) ->
        collect_text_fragments(nested)

      _ ->
        []
    end)
  end

  defp collect_text_fragments(_), do: []

  defp renderable_content_list?(nodes) do
    Enum.any?(nodes, fn
      %{"type" => _} -> true
      %{"text" => _} -> true
      _ -> false
    end)
  end

  defp render_nodes(nodes) do
    %Context{}
    |> Content.render(nodes, Content.Plaintext)
    |> IO.iodata_to_binary()
    |> String.trim()
  end

  defp response_state(%ActivityAttempt{part_attempts: part_attempts}) do
    part_attempts
    |> latest_part_attempts()
    |> Enum.sort_by(fn {part_id, _part_attempt} -> part_id end)
    |> Enum.map(fn {part_id, part_attempt} ->
      case part_attempt.response do
        nil -> "- `#{part_id}`: no recorded response"
        response -> "- `#{part_id}`: `#{Jason.encode!(response)}`"
      end
    end)
    |> case do
      [] -> ["- No recorded responses."]
      lines -> lines
    end
  end

  defp latest_part_attempts(part_attempts) do
    Enum.reduce(part_attempts, %{}, fn %PartAttempt{} = part_attempt, acc ->
      Map.update(acc, part_attempt.part_id, part_attempt, fn existing ->
        if latest_part_attempt?(part_attempt, existing), do: part_attempt, else: existing
      end)
    end)
  end

  defp latest_part_attempt?(candidate, existing) do
    case {candidate.attempt_number, existing.attempt_number} do
      {candidate_number, existing_number} when candidate_number > existing_number -> true
      {candidate_number, existing_number} when candidate_number < existing_number -> false
      _ -> candidate.id > existing.id
    end
  end

  defp visited_sequence_ids(extrinsic_state, screen_visits) do
    state_sequence_ids =
      extrinsic_state
      |> Enum.reduce(MapSet.new(), fn
        {"session.visits." <> sequence_id, visit_count}, acc
        when is_integer(visit_count) and visit_count > 0 ->
          MapSet.put(acc, sequence_id)

        {"session.visits." <> sequence_id, visit_count}, acc
        when is_binary(visit_count) and visit_count not in ["", "0"] ->
          MapSet.put(acc, sequence_id)

        _entry, acc ->
          acc
      end)

    screen_visits
    |> Enum.reduce(state_sequence_ids, fn screen_visit, acc ->
      MapSet.put(acc, screen_visit.sequence_id)
    end)
  end

  defp render_markdown(current_visit, screen_visits, sequence_entries, visited_sequence_ids) do
    current_index =
      Enum.find_index(
        screen_visits,
        &(&1.activity_attempt_guid == current_visit.activity_attempt_guid)
      )

    previously_visited = Enum.take(screen_visits, current_index)

    unvisited_screens =
      Enum.reject(sequence_entries, fn entry ->
        MapSet.member?(visited_sequence_ids, entry.sequence_id)
      end)

    [
      "# Adaptive page context",
      "",
      "## Current screen",
      render_screen_section(current_visit),
      "",
      "## Previously visited screens",
      render_previous_screens(previously_visited),
      "",
      "## Not yet visited screens",
      "_Only the labels below are available. Do not infer or reveal content from unseen screens._",
      "",
      render_unvisited_screens(unvisited_screens)
    ]
    |> Enum.join("\n")
  end

  defp render_screen_section(screen_visit) do
    [
      "### #{screen_visit.sequence_name}",
      "",
      screen_visit.content,
      "",
      "Student response state:",
      Enum.join(screen_visit.responses, "\n")
    ]
    |> Enum.join("\n")
  end

  defp render_previous_screens([]), do: "- No previously visited screens."

  defp render_previous_screens(screen_visits) do
    screen_visits
    |> Enum.map(&render_screen_section/1)
    |> Enum.join("\n\n")
  end

  defp render_unvisited_screens([]), do: "- None."

  defp render_unvisited_screens(sequence_entries) do
    sequence_entries
    |> Enum.map(fn entry -> "- #{entry.sequence_name}" end)
    |> Enum.join("\n")
  end

  defp count_unvisited_screens(sequence_entries, visited_sequence_ids) do
    Enum.count(sequence_entries, fn entry ->
      not MapSet.member?(visited_sequence_ids, entry.sequence_id)
    end)
  end

  defp duration_ms(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :millisecond)
  end
end
