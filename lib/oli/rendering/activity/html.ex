defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  require Logger

  @behaviour Oli.Rendering.Activity

  # TODO: move these adaptive sequence methods somewhere appropriate
  defp find_sequence_entry_by_activity_id(activity_id, entries) do
    entry = entries
      |> Enum.find(fn(%{"activity_id" => ref_activity_id}) -> ref_activity_id == activity_id end)

    case entry do
      nil -> Logger.error("Could not find sequence entry for activity_id: #{activity_id}")
      _ -> entry
    end
  end

  defp find_sequence_entry_by_sequence_id(sequence_id, entries) do
    entry = entries
      |> Enum.find(fn e ->
        custom = Map.get(e, "custom")
        ref_sequence_id = Map.get(custom, "sequenceId")
        ref_sequence_id == sequence_id
      end)

    case entry do
      nil -> Logger.error("Could not find sequence entry for sequence_id: #{sequence_id}")
      _ -> entry
    end
  end

  defp get_activity_lineage(activity_id, entries) do
    entry = find_sequence_entry_by_activity_id(activity_id, entries)
    lineage = [entry]
    custom = Map.get(entry, "custom")
    parent_sequence_id = Map.get(custom, "layerRef", nil)
    case parent_sequence_id do
      nil -> lineage
      _ ->
        %{"activity_id" => parent_activity_id} = find_sequence_entry_by_sequence_id(parent_sequence_id, entries)
        parent_lineage = get_activity_lineage(parent_activity_id, entries)
        parent_lineage |> List.insert_at(0, entry)
    end
  end

  defp get_flattened_activity_model(page_content, activity_id, activity_map) do
    Logger.debug("get_flattened_activity_model: #{activity_id}")
    # TODO: should check that this item is type of "group" rather than assuming
    [first | _tail] = page_content
    sequence_entries = Map.get(first, "children", [])
    Logger.debug("sequence_entries: #{sequence_entries |> Jason.encode!}")
    activity_lineage = get_activity_lineage(activity_id, sequence_entries)
    Logger.debug("activity_lineage (#{Enum.count(activity_lineage)}): #{activity_lineage |> Jason.encode!}")
    # need to take each item from the lineage, get the model for it, and then
    # merge all partsLayout into the final model
    activity_model = Enum.reduce(activity_lineage, %{}, fn lineage_entry, acc ->
      lineage_entry_activity_id = Map.get(lineage_entry, "activity_id")
      Logger.debug("lineage_entry_activity_id: #{lineage_entry_activity_id}")
      lineage_summary = activity_map[lineage_entry_activity_id]
      case lineage_summary do
        nil ->
          Logger.error("Could not find activity summary for lineage_entry_activity_id: #{lineage_entry_activity_id}")
          acc
        _ ->
          model = Poison.decode!(HtmlEntities.decode(lineage_summary.model))
          partsLayout = Map.get(model, "partsLayout", [])
          currentPartsLayout = Map.get(acc, "partsLayout", [])
          merged_parts_layout = Enum.concat(currentPartsLayout, partsLayout)
          model |> Map.put("partsLayout", merged_parts_layout)
      end
    end)
    Logger.debug("activity_model AFTER REDUCE: #{activity_model |> Jason.encode!}")

    sequence_entry = List.last(activity_lineage)
    # the activity_model needs the "id" to be the "sequenceId" from the sequence_entry
    activity_model |> Map.put("id", Map.get(sequence_entry, "custom") |> Map.get("sequenceId"))
    # finally it needs to be stringified again
    activity_model |> Poison.encode! |> HtmlEntities.encode
  end

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          mode: mode,
          user: user,
          resource_attempt: resource_attempt
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
    activity_summary = activity_map[activity_id]

    case activity_summary do
      nil ->
        {error_id, error_msg} =
          log_error(
            "ActivitySummary with id #{activity_id} missing from activity_map",
            {activity, activity_map}
          )

        if render_opts.render_errors do
          error(context, activity, {:activity_missing, error_id, error_msg})
        else
          []
        end

      _ ->
        tag =
          case mode do
            :instructor_preview -> activity_summary.authoring_element
            _ -> activity_summary.delivery_element
          end

        state = activity_summary.state
        graded = activity_summary.graded

        model_json = case tag do
          "oli-adaptive-delivery" ->
            page_model = Map.get(resource_attempt.content, "model")
            get_flattened_activity_model(page_model, activity_id, activity_map)

          _ -> activity_summary.model
        end


        section_slug = context.section_slug

        activity_html =
          case mode do
            :instructor_preview ->
              [
                "<#{tag} model=\"#{model_json}\" editmode=\"false\" projectSlug=\"#{section_slug}\"></#{tag}>\n"
              ]

            _ ->
              [
                "<#{tag} class=\"activity-container\" graded=\"#{graded}\" state=\"#{state}\" model=\"#{model_json}\" mode=\"#{mode}\" user_id=\"#{user.id}\" section_slug=\"#{section_slug}\"></#{tag}>\n"
              ]
          end

        # purposes types directly on activities is deprecated but rendering is left here to support legacy content
        case activity["purpose"] do
          nil ->
            activity_html

          "none" ->
            activity_html

          purpose ->
            [
              "<h4 class=\"activity-purpose ",
              Oli.Utils.Slug.slugify(purpose),
              "\">",
              Oli.Utils.Purposes.label_for(purpose),
              "</h4>",
              activity_html
            ]
        end
    end
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
