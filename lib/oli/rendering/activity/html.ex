defmodule Oli.Rendering.Activity.Html do
  @moduledoc """
  Implements the Html writer for activity rendering
  """
  import Oli.Utils

  alias Oli.Accounts
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Activities
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content.ResourceSummary
  alias Oli.Rendering.Error
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Adaptive.DynamicLinks.Telemetry, as: DynamicLinksTelemetry

  require Logger

  @unresolved_link_warning_cache_key :adaptive_unresolved_link_warning_ids
  @iframe_fallback_type "unresolved_internal_source"
  @iframe_fallback_message "This embedded page is unavailable."

  @behaviour Oli.Rendering.Activity

  defp get_activity_model("oli-adaptive-delivery", nil, _, _, model) do
    model
  end

  defp get_activity_model(tag, resource_attempt, activity_id, activity_map, model) do
    case tag do
      "oli-adaptive-delivery" ->
        page_model = Map.get(resource_attempt.content, "model")
        get_flattened_activity_model(page_model, activity_id, activity_map)

      _ ->
        model
    end
  end

  defp render_missing_activity(context, activity, _activity_map, activity_id, render_opts) do
    if render_opts.render_errors do
      error_id = uuid() |> String.upcase()
      error_msg = "ActivitySummary with id #{activity_id} missing from activity_map"

      error(context, activity, {:activity_missing, error_id, error_msg})
    else
      []
    end
  end

  defp is_adaptive?(tag) do
    String.starts_with?(tag, "oli-adaptive-")
  end

  defp render_activity_html(
         %Context{
           activity_map: activity_map,
           mode: mode,
           section_slug: section_slug,
           resource_attempt: resource_attempt,
           bib_app_params: bib_app_params
         } = context,
         %ActivitySummary{
           delivery_element: delivery_element,
           model: model,
           variables: variables
         } = summary,
         %{"activity_id" => activity_id}
       ) do
    tag =
      case mode do
        :instructor_preview -> instructor_preview_tag(summary)
        _ -> delivery_element
      end

    model_json =
      get_activity_model(tag, resource_attempt, activity_id, activity_map, model)
      |> resolve_adaptive_dynamic_links(tag, context)

    bib_params =
      Enum.reduce(bib_app_params, [], fn x, acc ->
        acc ++
          [%{"id" => x.id, "ordinal" => x.ordinal, "slug" => x.slug, "title" => x.title}]
      end)

    case mode do
      :instructor_preview ->
        {:ok, bib_params_json} = Jason.encode(bib_params)

        render_instructor_preview_html(
          tag,
          summary,
          context,
          section_slug,
          model_json,
          activity_id,
          variables,
          bib_params_json
        )

      :review ->
        if is_adaptive?(tag) do
          render_single_activity_html(tag, context, summary, bib_params, model_json, activity_id)
        else
          [
            render_historical_attempts(
              summary.id,
              context.historical_attempts,
              section_slug,
              context
            ),
            render_single_activity_html(
              tag,
              context,
              summary,
              bib_params,
              model_json,
              activity_id
            )
          ]
        end

      _ ->
        render_single_activity_html(tag, context, summary, bib_params, model_json, activity_id)
    end
  end

  defp render_historical_attempts(activity_id, historical_attempts, section_slug, context) do
    case historical_attempts do
      nil ->
        []

      _ ->
        case Map.get(historical_attempts, activity_id) do
          nil ->
            []

          [] ->
            []

          attempts ->
            {:safe, attempt_selector} =
              OliWeb.Common.React.component(
                context,
                "Components.AttemptSelector",
                %{
                  activityId: activity_id,
                  attempts:
                    Enum.map(attempts, fn a ->
                      %{
                        state: a.lifecycle_state,
                        attemptNumber: a.attempt_number,
                        attemptGuid: a.attempt_guid,
                        date:
                          Timex.format!(
                            a.updated_at,
                            "{Mfull} {D}, {YYYY} at {h12}:{m} {AM} {Zabbr}"
                          )
                      }
                    end),
                  sectionSlug: section_slug
                },
                id: "attempt-selector-#{activity_id}"
              )

            [attempt_selector]
        end
    end
  end

  defp render_single_activity_html(
         tag,
         %Context{
           mode: mode,
           user: user,
           resource_attempt: resource_attempt,
           extrinsic_state: extrinsic_state,
           group_id: group_id,
           survey_id: survey_id,
           learning_language: learning_language,
           effective_settings: effective_settings,
           render_opts: render_opts
         } = context,
         %ActivitySummary{
           state: state,
           graded: graded,
           aggregate_score: aggregate_score,
           aggregate_out_of: aggregate_out_of,
           aggregate_includes_current_attempt: aggregate_includes_current_attempt,
           variables: variables,
           ordinal: ordinal
         },
         bib_params,
         model_json,
         resource_id
       ) do
    page_link_params =
      cond do
        is_nil(context.page_link_params) -> %{}
        true -> Enum.into(context.page_link_params, %{})
      end

    activity_context =
      %{
        resourceId: resource_id,
        graded: graded,
        batchScoring: effective_settings && effective_settings.batch_scoring,
        oneAtATime: effective_settings && effective_settings.assessment_mode == :one_at_a_time,
        maxAttempts: effective_settings && effective_settings.max_attempts,
        scoringStrategyId: effective_settings && effective_settings.scoring_strategy_id,
        replacementStrategy: effective_settings && effective_settings.replacement_strategy,
        aggregateScore: aggregate_score,
        aggregateOutOf: aggregate_out_of,
        aggregateIncludesCurrentAttempt: aggregate_includes_current_attempt,
        ordinal: ordinal,
        userId: user.id,
        sectionSlug: context.section_slug,
        projectSlug: context.project_slug,
        surveyId: survey_id,
        groupId: group_id,
        bibParams: bib_params,
        learningLanguage: learning_language,
        showFeedback: Settings.show_feedback?(effective_settings),
        pageAttemptGuid:
          if is_nil(resource_attempt) do
            ""
          else
            resource_attempt.attempt_guid
          end,
        pageState: extrinsic_state || %{},
        renderPointMarkers: render_opts.render_point_markers,
        isAnnotationLevel: true,
        variables: variables,
        pageLinkParams: page_link_params,
        allowHints: effective_settings && effective_settings.allow_hints
      }
      |> maybe_put_show_math_previews(tag, user)
      |> Poison.encode!()
      |> HtmlEntities.encode()

    activity_resource_id =
      if mode == :review,
        do: "activity-#{resource_id}-#{Ecto.UUID.generate()}}",
        else: "activity-#{resource_id}"

    [
      ~s|<#{tag} id="#{activity_resource_id}" phx-update="ignore" class="activity-container" state="#{state}" model="#{model_json}" mode="#{mode}" context="#{activity_context}"></#{tag}>\n|
    ]
  end

  defp maybe_put_show_math_previews(activity_context, "oli-adaptive-delivery", _user),
    do: activity_context

  defp maybe_put_show_math_previews(activity_context, _tag, user) do
    Map.put(activity_context, :showMathPreviews, show_math_previews?(user))
  end

  defp show_math_previews?(%Oli.Accounts.User{} = user) do
    Accounts.get_user_preference(user, :show_math_previews?, true)
  end

  defp show_math_previews?(_), do: true

  defp resolve_adaptive_dynamic_links(model_json, tag, %Context{} = context) do
    if is_adaptive?(tag) and dynamic_link_markers_present?(model_json) do
      with {:ok, decoded_model} <- decode_activity_model(model_json),
           {rewired_model, _cache, changed?} <-
             rewrite_adaptive_internal_links(decoded_model, context, %{}) do
        if changed? do
          with {:ok, encoded_model} <- Jason.encode(rewired_model) do
            ActivityContext.encode(encoded_model)
          else
            _ -> model_json
          end
        else
          model_json
        end
      else
        _ -> model_json
      end
    else
      model_json
    end
  end

  defp dynamic_link_markers_present?(model_json) when is_binary(model_json) do
    String.contains?(model_json, "idref") or
      String.contains?(model_json, "resource_id") or
      String.contains?(model_json, "/course/link/")
  end

  defp dynamic_link_markers_present?(_), do: false

  defp decode_activity_model(model_json) when is_binary(model_json) do
    model_json
    |> HtmlEntities.decode()
    |> Jason.decode()
  end

  defp rewrite_adaptive_internal_links(value, _context, cache) when is_binary(value),
    do: {value, cache, false}

  defp rewrite_adaptive_internal_links(value, _context, cache) when is_number(value),
    do: {value, cache, false}

  defp rewrite_adaptive_internal_links(value, _context, cache) when is_boolean(value),
    do: {value, cache, false}

  defp rewrite_adaptive_internal_links(nil, _context, cache), do: {nil, cache, false}

  defp rewrite_adaptive_internal_links(items, context, cache) when is_list(items) do
    {rewritten_items, cache, changed?} =
      Enum.reduce(items, {[], cache, false}, fn item, {acc, cache, changed?} ->
        {rewritten_item, cache, item_changed?} =
          rewrite_adaptive_internal_links(item, context, cache)

        {[rewritten_item | acc], cache, changed? || item_changed?}
      end)

    if changed? do
      {Enum.reverse(rewritten_items), cache, true}
    else
      {items, cache, false}
    end
  end

  defp rewrite_adaptive_internal_links(item, context, cache) when is_map(item) do
    {rewritten_item, cache, children_changed?} =
      Enum.reduce(item, {item, cache, false}, fn {key, value}, {acc, cache, changed?} ->
        if is_map(value) or is_list(value) do
          {rewired_value, cache, value_changed?} =
            rewrite_adaptive_internal_links(value, context, cache)

          if value_changed? do
            {Map.put(acc, key, rewired_value), cache, true}
          else
            {acc, cache, changed?}
          end
        else
          {acc, cache, changed?}
        end
      end)

    {rewritten_item, cache, anchor_changed?} =
      maybe_rewrite_adaptive_anchor(rewritten_item, context, cache)

    {rewritten_item, cache, iframe_changed?} =
      maybe_rewrite_adaptive_iframe(rewritten_item, context, cache)

    {rewritten_item, cache, children_changed? || anchor_changed? || iframe_changed?}
  end

  defp rewrite_adaptive_internal_links(value, _context, cache), do: {value, cache, false}

  defp maybe_rewrite_adaptive_anchor(%{"tag" => "a"} = item, %Context{} = context, cache) do
    idref = Map.get(item, "idref") || Map.get(item, "resource_id")
    href = Map.get(item, "href")

    cond do
      not is_nil(idref) ->
        start_time = System.monotonic_time()

        with {:ok, resource_id} <- normalize_resource_id(idref),
             {:ok, slug, cache} <- resolve_revision_slug(resource_id, context, cache) do
          DynamicLinksTelemetry.delivery_resolved(
            duration_ms(start_time),
            dynamic_link_metadata(context, resource_id,
              reason: "resolved",
              source: "delivery_render"
            )
          )

          {rewrite_adaptive_anchor(item, internal_href(context, slug)), cache, true}
        else
          {:error, cache} ->
            emit_resolution_failure_telemetry(context, idref, "resource_not_found")
            cache = maybe_log_unresolved_dynamic_link_warning(cache, idref)

            {fallback_adaptive_anchor(item, context), cache, true}

          _ ->
            emit_resolution_failure_telemetry(context, idref, "invalid_resource_id")
            cache = maybe_log_unresolved_dynamic_link_warning(cache, idref)

            {fallback_adaptive_anchor(item, context), cache, true}
        end

      internal_course_link?(href) ->
        case internal_slug_from_href(href) do
          {:ok, slug} ->
            {rewrite_adaptive_anchor(item, internal_href(context, slug)), cache, true}

          :error ->
            {item, cache, false}
        end

      true ->
        {item, cache, false}
    end
  end

  defp maybe_rewrite_adaptive_anchor(item, _context, cache), do: {item, cache, false}

  defp maybe_rewrite_adaptive_iframe(
         %{"type" => "janus-capi-iframe"} = item,
         %Context{} = context,
         cache
       ) do
    src = Map.get(item, "src")
    idref = Map.get(item, "idref") || Map.get(item, "resource_id")
    source_type = Map.get(item, "sourceType")
    link_type = Map.get(item, "linkType")

    is_internal =
      internal_course_link?(src) or source_type == "page" or link_type == "page" or
        not is_nil(idref)

    if is_internal do
      cond do
        not is_nil(idref) ->
          start_time = System.monotonic_time()

          with {:ok, resource_id} <- normalize_resource_id(idref),
               {:ok, slug, cache} <- resolve_revision_slug(resource_id, context, cache) do
            DynamicLinksTelemetry.delivery_resolved(
              duration_ms(start_time),
              dynamic_link_metadata(context, resource_id,
                reason: "resolved",
                source: "iframe_delivery_render"
              )
            )

            {rewrite_adaptive_iframe(item, internal_href(context, slug)), cache, true}
          else
            {:error, cache} ->
              emit_resolution_failure_telemetry(
                context,
                idref,
                "resource_not_found",
                "iframe_delivery_render"
              )

              cache = maybe_log_unresolved_dynamic_link_warning(cache, idref)

              {fallback_adaptive_iframe(item, context), cache, true}

            _ ->
              emit_resolution_failure_telemetry(
                context,
                idref,
                "invalid_resource_id",
                "iframe_delivery_render"
              )

              cache = maybe_log_unresolved_dynamic_link_warning(cache, idref)

              {fallback_adaptive_iframe(item, context), cache, true}
          end

        internal_course_link?(src) ->
          case internal_slug_from_href(src) do
            {:ok, slug} ->
              {rewrite_adaptive_iframe(item, internal_href(context, slug)), cache, true}

            :error ->
              emit_resolution_failure_telemetry(
                context,
                src,
                "invalid_internal_href",
                "iframe_delivery_render"
              )

              cache = maybe_log_unresolved_dynamic_link_warning(cache, src)
              {fallback_adaptive_iframe(item, context), cache, true}
          end

        true ->
          emit_resolution_failure_telemetry(
            context,
            idref || src,
            "invalid_internal_source",
            "iframe_delivery_render"
          )

          cache = maybe_log_unresolved_dynamic_link_warning(cache, idref || src)
          {fallback_adaptive_iframe(item, context), cache, true}
      end
    else
      {item, cache, false}
    end
  end

  defp maybe_rewrite_adaptive_iframe(item, _context, cache), do: {item, cache, false}

  defp maybe_log_unresolved_dynamic_link_warning(cache, idref) do
    warned_ids = Map.get(cache, @unresolved_link_warning_cache_key, MapSet.new())

    if MapSet.member?(warned_ids, idref) do
      cache
    else
      Logger.warning(
        "Unable to resolve adaptive dynamic link idref #{inspect(idref)}; using fallback"
      )

      Map.put(cache, @unresolved_link_warning_cache_key, MapSet.put(warned_ids, idref))
    end
  end

  defp rewrite_adaptive_anchor(item, href) do
    item
    |> Map.put("href", href)
    |> Map.put("target", "_blank")
    |> Map.put("rel", "noopener noreferrer")
    |> Map.delete("idref")
    |> Map.delete("resource_id")
  end

  defp rewrite_adaptive_iframe(item, src) do
    item
    |> Map.put("src", src)
    |> Map.delete("idref")
    |> Map.delete("resource_id")
    |> Map.delete("dynamicLinkFallback")
  end

  defp normalize_resource_id(resource_id) when is_integer(resource_id), do: {:ok, resource_id}

  defp normalize_resource_id(resource_id) when is_binary(resource_id) do
    case Integer.parse(resource_id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> :error
    end
  end

  defp normalize_resource_id(_), do: :error

  defp internal_course_link?(href) when is_binary(href),
    do: String.starts_with?(href, "/course/link/")

  defp internal_course_link?(_), do: false

  defp internal_slug_from_href("/course/link/" <> rest) do
    case String.split(rest, ["?", "#"], parts: 2) do
      [slug | _] when slug != "" -> {:ok, slug}
      _ -> :error
    end
  end

  defp internal_slug_from_href(_), do: :error

  defp resolve_revision_slug(resource_id, %Context{} = context, cache) do
    case Map.get(cache, resource_id) do
      {:ok, slug} ->
        {:ok, slug, cache}

      :error ->
        {:error, cache}

      nil ->
        case fetch_revision_slug(resource_id, context) do
          {:ok, slug} ->
            {:ok, slug, Map.put(cache, resource_id, {:ok, slug})}

          :error ->
            {:error, Map.put(cache, resource_id, :error)}
        end
    end
  end

  defp fetch_revision_slug(resource_id, %Context{resource_summary_fn: resource_summary_fn}) do
    if is_nil(resource_summary_fn) do
      :error
    else
      try do
        case resource_summary_fn.(resource_id) do
          %ResourceSummary{slug: slug} when is_binary(slug) -> {:ok, slug}
          _ -> :error
        end
      rescue
        _ -> :error
      end
    end
  end

  defp internal_href(
         %Context{section_slug: section_slug, page_link_params: page_link_params},
         revision_slug
       )
       when is_binary(section_slug) do
    params =
      cond do
        is_nil(page_link_params) -> %{}
        true -> page_link_params
      end

    query = URI.encode_query(params)

    if query == "" do
      "/sections/#{section_slug}/lesson/#{revision_slug}"
    else
      "/sections/#{section_slug}/lesson/#{revision_slug}?#{query}"
    end
  end

  defp internal_href(%Context{}, revision_slug), do: "/course/link/#{revision_slug}"

  defp fallback_adaptive_anchor(item, %Context{page_link_params: page_link_params}) do
    item
    |> Map.put("href", fallback_request_path(page_link_params))
    |> Map.put("target", "_self")
  end

  defp fallback_adaptive_iframe(item, %Context{page_link_params: page_link_params}) do
    item
    |> Map.put("src", "about:blank")
    |> Map.put("dynamicLinkFallback", %{
      "type" => @iframe_fallback_type,
      "message" => @iframe_fallback_message,
      "href" => fallback_request_path(page_link_params)
    })
    |> Map.delete("idref")
    |> Map.delete("resource_id")
  end

  defp fallback_request_path(page_link_params) do
    cond do
      is_list(page_link_params) ->
        Keyword.get(page_link_params, :request_path, "#")

      is_map(page_link_params) ->
        Map.get(page_link_params, :request_path) ||
          Map.get(page_link_params, "request_path", "#")

      true ->
        "#"
    end
  end

  defp emit_resolution_failure_telemetry(context, idref, reason, source \\ "delivery_render") do
    resource_id =
      case normalize_resource_id(idref) do
        {:ok, normalized} -> normalized
        _ -> nil
      end

    metadata =
      dynamic_link_metadata(context, resource_id, reason: reason, source: source)

    DynamicLinksTelemetry.delivery_resolution_failed(metadata)
    DynamicLinksTelemetry.delivery_broken_clicked(%{metadata | reason: "fallback_rendered"})
  end

  defp dynamic_link_metadata(%Context{} = context, resource_id, extra) do
    %{
      project_slug: context.project_slug,
      section_slug: context.section_slug,
      target_resource_id: resource_id,
      source: Keyword.get(extra, :source, "unknown"),
      reason: Keyword.get(extra, :reason, "unknown")
    }
  end

  defp duration_ms(start_time) do
    System.monotonic_time()
    |> Kernel.-(start_time)
    |> System.convert_time_unit(:native, :millisecond)
    |> max(0)
  end

  defp possibly_wrap_with_numbering(activity_html, %ActivitySummary{ordinal: _}),
    do: activity_html

  defp possibly_wrap_in_purpose(activity_html, activity) do
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

  defp render_activity(
         %Context{} = context,
         %ActivitySummary{} = summary,
         activity
       ) do
    render_activity_html(context, summary, activity)
    |> possibly_wrap_with_numbering(summary)
    |> possibly_wrap_in_purpose(activity)
  end

  def activity(
        %Context{
          activity_map: activity_map,
          render_opts: render_opts
        } = context,
        %{"activity_id" => activity_id} = activity
      ) do
    activity_summary = activity_map[activity_id]

    case activity_summary do
      nil ->
        render_missing_activity(context, activity, activity_map, activity_id, render_opts)

      %ActivitySummary{} = activity_summary ->
        render_activity(context, activity_summary, activity)
    end
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end

  # ---------------
  # HELPERS

  defp instructor_preview_tag(%ActivitySummary{
         preview_element: preview_element,
         authoring_element: authoring_element
       }) do
    preview_element || authoring_element
  end

  defp render_instructor_preview_html(
         tag,
         %ActivitySummary{
           preview_element: preview_element,
           preview_context: preview_context
         } = summary,
         %Context{
           student_responses: student_responses
         },
         section_slug,
         model_json,
         activity_id,
         variables,
         bib_params_json
       ) do
    activity_html_id = get_activity_html_id(activity_id, model_json)

    case preview_element do
      nil ->
        warn_supported_preview_fallback(summary)

        # Activities without a dedicated preview component still render inside the
        # instructor-preview card chrome. In that case we wrap the authoring element with the
        # same header/actions shell so Remove/Restore and removed styling behave like preview
        # components, while the inner activity body continues to use authoring-mode rendering.
        # (Activities whose types are treated as preview-capable on the Elixir side are listed by
        # Oli.Activities.preview_supported_activity_slugs/0.)
        activity_context =
          %{
            variables: variables,
            previewMode: "instructor"
          }
          |> Poison.encode!()
          |> HtmlEntities.encode()

        student_responses =
          student_responses
          |> Kernel.||(%{})
          |> Poison.encode!()
          |> HtmlEntities.encode()

        wrapper_class =
          preview_wrapper_class(preview_context, padded?: true, authoring_fallback?: true)

        [
          ~s|<div class="#{wrapper_class}">|,
          render_preview_header(preview_context, activity_id),
          ~s|<#{tag} authoringcontext="#{activity_context}" student_responses=\"#{student_responses}\" section_slug=\"#{section_slug}\" activity_id=\"#{activity_html_id}\" model="#{model_json}" activityId="#{activity_id}" editmode="false" mode="instructor_preview" projectSlug="#{section_slug}" bib_params="#{Base.encode64(bib_params_json)}"></#{tag}>\n|,
          render_learning_objectives(preview_context),
          ~s|</div>|
        ]

      _ ->
        preview_context =
          Map.merge(preview_context || %{}, %{
            activityId: activity_id,
            activityHtmlId: activity_html_id,
            sectionSlug: section_slug,
            bibParams: %{
              encoded: Base.encode64(bib_params_json)
            },
            variables: variables
          })
          |> Poison.encode!()
          |> HtmlEntities.encode()

        [
          ~s|<div class="instructor-preview-activity-wrapper mb-6 rounded-lg border border-Border-border-default bg-Surface-surface-primary overflow-hidden">|,
          ~s|<#{tag} previewcontext="#{preview_context}" section_slug="#{section_slug}" activity_id="#{activity_html_id}" model="#{model_json}" activityId="#{activity_id}" mode="preview" projectSlug="#{section_slug}" bib_params="#{Base.encode64(bib_params_json)}"></#{tag}>\n|,
          ~s|</div>|
        ]
    end
  end

  defp warn_supported_preview_fallback(%ActivitySummary{
         activity_type_slug: activity_type_slug,
         id: activity_id
       }) do
    if Activities.preview_supported_activity_slug?(activity_type_slug) do
      Logger.warning(
        "Instructor preview falling back to authoring element for supported activity type #{activity_type_slug} on activity #{activity_id}"
      )
    end
  end

  defp render_preview_header(nil, _activity_id), do: []

  # Shared header renderer for instructor preview cards. It now serves both true preview
  # components and authoring-element fallbacks, so the action button/pill contract must remain
  # server-renderable and not depend on React-only state. (Preview-capable activity types are the
  # ones surfaced in Elixir through Oli.Activities.preview_supported_activity_slugs/0.)
  defp render_preview_header(preview_context, activity_id) do
    activity_type_label =
      Map.get(preview_context, :activityTypeLabel) ||
        Map.get(preview_context, "activityTypeLabel")

    title = Map.get(preview_context, :title) || Map.get(preview_context, "title")
    points = Map.get(preview_context, :points) || Map.get(preview_context, "points")
    status_pill = Map.get(preview_context, :statusPill) || Map.get(preview_context, "statusPill")
    actions = Map.get(preview_context, :actions) || Map.get(preview_context, "actions") || []

    can_customize =
      Map.get(preview_context, :canCustomize) || Map.get(preview_context, "canCustomize")

    target =
      Map.get(preview_context, :customizationTarget) ||
        Map.get(preview_context, "customizationTarget")

    points_label =
      case points do
        nil -> nil
        value -> "#{format_preview_points(value)} #{preview_points_unit(value)}"
      end

    metadata =
      case {activity_type_label, points_label} do
        {nil, nil} ->
          ""

        {label, nil} ->
          ~s|<span>#{HtmlEntities.encode(label)}</span>|

        {nil, label} ->
          ~s|<span>#{HtmlEntities.encode(label)}</span>|

        {label, points_text} ->
          ~s|<span>#{HtmlEntities.encode(label)}</span><span aria-hidden="true">&bull;</span><span>#{HtmlEntities.encode(points_text)}</span>|
      end

    title_html =
      case title do
        nil ->
          ""

        value ->
          ~s|<h3 class="!m-0 text-xl font-semibold leading-[26px] text-Text-text-high">#{HtmlEntities.encode(value)}</h3>|
      end

    status_pill_html =
      render_preview_status_pill(status_pill)

    title_row_html =
      if title_html == "" and status_pill_html == "" do
        ""
      else
        ~s|<div data-preview-title-row="#{activity_id}" class="flex flex-wrap items-center gap-3">#{title_html}#{status_pill_html}</div>|
      end

    actions_html =
      render_preview_header_actions(can_customize, actions, target, activity_id)

    [
      ~s|<header class="mb-4 flex flex-col gap-3">|,
      ~s|<div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between sm:gap-4">|,
      ~s|<div class="flex min-w-0 flex-col gap-2">|,
      ~s|<div class="flex flex-wrap items-center gap-3 text-sm font-normal leading-[21px] text-Text-text-low-alpha">#{metadata}</div>|,
      title_row_html,
      ~s|</div>|,
      actions_html,
      ~s|</div>|,
      ~s|</header>|
    ]
  end

  defp render_preview_status_pill(nil), do: ""

  defp render_preview_status_pill(%{kind: kind, label: label}),
    do: render_preview_status_pill(%{"kind" => kind, "label" => label})

  defp render_preview_status_pill(%{"kind" => "removed", "label" => label}) do
    ~s|<span data-preview-status-pill class="inline-flex items-center rounded-full border border-Border-border-danger bg-[rgba(255,64,64,0.08)] px-4 py-1 font-open-sans text-[14px] font-semibold leading-4 tracking-normal text-[#C91414] dark:bg-[rgba(255,64,64,0.16)] dark:text-[#FFB5B7]">#{HtmlEntities.encode(label)}</span>|
  end

  defp render_preview_status_pill(_), do: ""

  defp render_preview_header_actions(false, _actions, _target, _activity_id), do: ""
  defp render_preview_header_actions(_can_customize, [], _target, _activity_id), do: ""
  defp render_preview_header_actions(_can_customize, _actions, nil, _activity_id), do: ""

  defp render_preview_header_actions(_can_customize, actions, target, activity_id) do
    buttons =
      Enum.map_join(actions, "", fn action ->
        render_preview_action_button(action, target)
      end)

    ~s|<div class="w-full sm:w-auto sm:shrink-0"><div data-preview-action-container="#{activity_id}" class="flex flex-wrap items-center gap-2">#{buttons}</div></div>|
  end

  defp render_preview_action_button(%{kind: kind, label: label}, target),
    do: render_preview_action_button(%{"kind" => kind, "label" => label}, target)

  defp render_preview_action_button(%{"kind" => kind, "label" => label}, target)
       when kind in ["remove", "restore"] do
    encoded_target =
      target
      |> Poison.encode!()
      |> HtmlEntities.encode()

    classes = preview_action_button_classes(kind)
    icon = if kind == "remove", do: trash_action_icon(), else: restore_action_icon()

    ~s|<button type="button" data-preview-customization-action="#{kind}" data-preview-customization-target="#{encoded_target}" data-preview-customization-button class="#{classes}">#{icon}<span data-preview-customization-label>#{HtmlEntities.encode(label)}</span></button>|
  end

  defp render_preview_action_button(_, _), do: ""

  defp preview_action_button_classes("remove") do
    "inline-flex items-center gap-2 rounded-[6px] border bg-Surface-surface-primary px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 border-Border-border-danger text-Specially-Tokens-Text-text-button-pill-muted hover:bg-[rgba(255,64,64,0.08)] dark:border-Border-border-danger dark:text-[#FFB5B7] dark:hover:bg-[rgba(255,64,64,0.18)] focus-visible:outline-Border-border-danger disabled:cursor-wait disabled:opacity-70"
  end

  defp preview_action_button_classes("restore") do
    "inline-flex items-center gap-2 rounded-[6px] border bg-transparent px-4 py-2 font-open-sans text-[14px] font-semibold leading-4 tracking-normal shadow-[0px_2px_4px_rgba(0,52,99,0.10)] transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 border-[#8AB8E5] text-Text-text-button hover:bg-[#EEF6FF] hover:text-Text-text-button-hover dark:bg-transparent dark:border-[#4C82B8] dark:text-[#9FD0FF] dark:hover:bg-[#16395C] dark:hover:text-[#D7ECFF] focus-visible:outline-[#8AB8E5] disabled:cursor-wait disabled:opacity-70"
  end

  # The authoring fallback and the preview-component path both use the same outer wrapper
  # contract so the client hook can toggle removed/default styling from a LiveView reply.
  defp preview_wrapper_class(preview_context, opts) do
    padded? = Keyword.get(opts, :padded?, false)
    authoring_fallback? = Keyword.get(opts, :authoring_fallback?, false)

    visual_state =
      Map.get(preview_context || %{}, :visualState) ||
        Map.get(preview_context || %{}, "visualState")

    classes = [
      "instructor-preview-activity-wrapper mb-6 rounded-lg border border-Border-border-default overflow-hidden",
      if(authoring_fallback?, do: "instructor-preview-authoring-fallback", else: nil),
      if(visual_state == "removed",
        do: "instructor-preview-removed",
        else: "instructor-preview-default"
      ),
      if(padded?, do: "p-6", else: nil),
      if(visual_state == "removed",
        do:
          "relative bg-Surface-surface-secondary-muted dark:bg-Background-bg-primary before:absolute before:inset-y-0 before:left-0 before:w-[6px] before:bg-Border-border-danger",
        else: "bg-Surface-surface-primary"
      )
    ]

    classes
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  defp trash_action_icon do
    ~s|<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3 6H5H21" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M19 6V20C19 20.5304 18.7893 21.0391 18.4142 21.4142C18.0391 21.7893 17.5304 22 17 22H7C6.46957 22 5.96086 21.7893 5.58579 21.4142C5.21071 21.0391 5 20.5304 5 20V6M8 6V4C8 3.46957 8.21071 2.96086 8.58579 2.58579C8.96086 2.21071 9.46957 2 10 2H14C14.5304 2 15.0391 2.21071 15.4142 2.58579C15.7893 2.96086 16 3.46957 16 4V6" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M10 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 11V17" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>|
  end

  defp restore_action_icon do
    ~s|<svg aria-hidden="true" class="h-4 w-4" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M3.33301 9.16667C3.33301 12.3883 5.94468 15 9.16634 15C12.388 15 14.9997 12.3883 14.9997 9.16667C14.9997 5.94501 12.388 3.33334 9.16634 3.33334C7.24384 3.33334 5.53848 4.2628 4.47595 5.69884" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/><path d="M5.00033 1.66666L5.00033 5.83332L9.16699 5.83332" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>|
  end

  defp format_preview_points(points) when is_float(points) do
    rounded = round(points)

    if points == rounded do
      Integer.to_string(rounded)
    else
      :erlang.float_to_binary(points, [:compact, decimals: 2])
    end
  end

  defp format_preview_points(points) when is_integer(points), do: Integer.to_string(points)
  defp format_preview_points(points), do: to_string(points)

  defp preview_points_unit(points) when points in [1, 1.0], do: "point"
  defp preview_points_unit(_points), do: "points"

  defp render_learning_objectives(nil), do: []

  defp render_learning_objectives(preview_context) do
    preview_context
    |> learning_objectives_from_context()
    |> case do
      [] ->
        []

      objectives ->
        rows =
          Enum.map_join(objectives, "", fn objective ->
            encoded_objective = HtmlEntities.encode(objective)

            ~s|<div class="flex items-baseline gap-2 min-w-0"><div class="shrink-0 whitespace-nowrap font-open-sans text-[12px] font-bold uppercase leading-[12px] tracking-normal text-Text-text-low-alpha">LO</div><div class="min-w-0 flex-1 font-open-sans text-[14px] font-normal leading-[16px] tracking-normal text-Text-text-high">#{encoded_objective}</div></div>|
          end)

        [
          ~s|<section class="flex flex-col gap-3 self-stretch">#{rows}</section>\n|
        ]
    end
  end

  defp learning_objectives_from_context(preview_context) do
    Map.get(preview_context, :learningObjectives) ||
      Map.get(preview_context, "learningObjectives") ||
      []
  end

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
