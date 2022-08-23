defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error
  alias Oli.Rendering.Activity.ActivitySummary

  require Logger

  @behaviour Oli.Rendering.Activity

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts,
          mode: mode,
          user: user,
          resource_attempt: resource_attempt,
          group_id: group_id,
          survey_id: survey_id,
          bib_app_params: bib_app_params
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
    activity_summary = activity_map[activity_id]

    bib_params =
      Enum.reduce(bib_app_params, [], fn x, acc ->
        acc ++ [%{"id" => x.id, "ordinal" => x.ordinal, "slug" => x.slug, "title" => x.title}]
      end)

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

      %ActivitySummary{
        authoring_element: authoring_element,
        delivery_element: delivery_element,
        state: state,
        graded: graded,
        model: model
      } ->
        tag =
          case mode do
            :instructor_preview -> authoring_element
            _ -> delivery_element
          end

        model_json =
          case tag do
            "oli-adaptive-delivery" ->
              page_model = Map.get(resource_attempt.content, "model")
              get_flattened_activity_model(page_model, activity_id, activity_map)

            _ ->
              model
          end

        section_slug = context.section_slug

        activity_html_id = get_activity_html_id(activity_id, model_json)

        # See DeliveryElement.ts for a definition of the corresponding client-side type ActivityContext
        activity_context =
          %{
            graded: graded,
            userId: user.id,
            sectionSlug: section_slug,
            surveyId: survey_id,
            groupId: group_id,
            bibParams: bib_params,
            pageAttemptGuid:
              if is_nil(resource_attempt) do
                ""
              else
                resource_attempt.attempt_guid
              end
          }
          |> Poison.encode!()
          |> HtmlEntities.encode()

        activity_html =
          case mode do
            :instructor_preview ->
              {:ok, bib_params_json} = Jason.encode(bib_params)

              [
                ~s|<#{tag} activity_id=\"#{activity_html_id}\" model="#{model_json}" editmode="false" projectSlug="#{section_slug}" bib_params="#{Base.encode64(bib_params_json)}"></#{tag}>\n|
              ]

            _ ->
              [
                ~s|<#{tag} class="activity-container" state="#{state}" model="#{model_json}" mode="#{mode}"  context="#{activity_context}"></#{tag}>\n|
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
              ~s|<h4 class="activity-purpose |,
              Oli.Utils.Slug.slugify(purpose),
              ~s|">|,
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

  # ---------------
  # HELPERS

  defp get_activity_html_id(activity_id, model_json) do
    model_json
    |> HtmlEntities.decode()
    |> Poison.decode!()
    |> Map.get("id", "activity_#{activity_id}")
  end

  defp get_flattened_activity_model(page_content, activity_id, activity_map) do
    Logger.debug("get_flattened_activity_model: #{activity_id}")

    sequence_entries = page_content |> List.first(%{}) |> Map.get("children", [])
    Logger.debug("sequence_entries: #{sequence_entries |> Jason.encode!()}")

    activity_lineage = get_activity_lineage(activity_id, sequence_entries)

    Logger.debug(
      "activity_lineage (#{Enum.count(activity_lineage)}): #{activity_lineage |> Jason.encode!()}"
    )

    # need to take each item from the lineage, get the model for it, and then
    # merge all partsLayout into the final model
    activity_model =
      Enum.reduce(activity_lineage, %{}, fn lineage_entry, acc ->
        lineage_entry_activity_id = Map.get(lineage_entry, "activity_id")
        Logger.debug("lineage_entry_activity_id: #{lineage_entry_activity_id}")

        case activity_map[lineage_entry_activity_id] do
          nil ->
            Logger.error(
              "Could not find activity summary for lineage_entry_activity_id: #{lineage_entry_activity_id}"
            )

            acc

          lineage_summary ->
            model = lineage_summary.model |> HtmlEntities.decode() |> Poison.decode!()
            parts_layout = Map.get(model, "partsLayout", [])
            current_parts_layout = Map.get(acc, "partsLayout", [])

            Map.put(model, "partsLayout", Enum.concat(parts_layout, current_parts_layout))
        end
      end)

    Logger.debug("activity_model AFTER REDUCE: #{activity_model |> Jason.encode!()}")

    # the activity_model needs the "id" to be the "sequenceId" from the sequence_entry
    sequence_entry = List.last(activity_lineage)
    activity_sequence_id = sequence_entry |> Map.get("custom", %{}) |> Map.get("sequenceId")
    Logger.debug("activity_sequence_id: #{activity_sequence_id}")

    activity_model = Map.put(activity_model, "id", activity_sequence_id)

    # finally it needs to be stringified again
    activity_model |> Poison.encode!() |> HtmlEntities.encode()
  end

  defp get_activity_lineage(activity_id, entries) do
    entry = find_sequence_entry_by_activity_id(activity_id, entries)
    parent_sequence_id = entry |> Map.get("custom", %{}) |> Map.get("layerRef", nil)

    case parent_sequence_id do
      nil ->
        [entry]

      _ ->
        %{"activity_id" => parent_activity_id} =
          find_sequence_entry_by_sequence_id(parent_sequence_id, entries)

        parent_lineage = get_activity_lineage(parent_activity_id, entries)

        List.insert_at(parent_lineage, -1, entry)
    end
  end

  defp find_sequence_entry_by_activity_id(activity_id, entries) do
    entry =
      Enum.find(entries, fn %{"activity_id" => ref_activity_id} ->
        ref_activity_id == activity_id
      end)

    case entry do
      nil -> Logger.error("Could not find sequence entry for activity_id: #{activity_id}")
      _ -> entry
    end
  end

  defp find_sequence_entry_by_sequence_id(sequence_id, entries) do
    entry =
      Enum.find(entries, fn e ->
        e |> Map.get("custom", %{}) |> Map.get("sequenceId") == sequence_id
      end)

    case entry do
      nil -> Logger.error("Could not find sequence entry for sequence_id: #{sequence_id}")
      _ -> entry
    end
  end
end
