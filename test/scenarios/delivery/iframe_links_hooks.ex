defmodule Oli.Scenarios.Delivery.IframeLinksHooks do
  @moduledoc """
  Hooks for adaptive iframe dynamic-link scenario coverage.
  """

  import ExUnit.Assertions

  alias Oli.Resources
  alias Oli.Scenarios.DirectiveTypes.ExecutionState
  alias Oli.Scenarios.Engine
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Context
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Rendering.Content.ResourceSummary
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Interop.Ingest.Processing.Rewiring
  alias Oli.Ingest.RewireLinks
  alias Oli.Publishing.ChangeTracker

  @project_name "iframe_project"
  @outside_project_name "outside_project"
  @section_name "iframe_section"
  @activity_title "Adaptive Iframe Activity"
  @activity_virtual_id "adaptive_iframe"
  @source_page_title "Source Page"
  @target_page_title "Target Page"
  @outside_page_title "Outside Page"

  def bind_iframe_to_target_page(%ExecutionState{} = state) do
    with {:ok, built_project} <- fetch_project(state, @project_name),
         {:ok, activity_revision} <- fetch_activity_revision(state),
         {:ok, target_revision} <- fetch_page_revision(built_project, @target_page_title),
         {:ok, updated_revision} <-
           update_iframe_target(
             built_project.project.slug,
             activity_revision,
             target_revision
           ),
         {:ok, updated_state} <- update_activity_refs(state, updated_revision) do
      updated_state
    else
      {:error, reason} ->
        flunk("bind_iframe_to_target_page failed: #{inspect(reason)}")
    end
  end

  def assert_iframe_rewiring_support(%ExecutionState{} = state) do
    with {:ok, built_project} <- fetch_project(state, @project_name),
         {:ok, activity_revision} <- fetch_activity_revision(state),
         {:ok, target_revision} <- fetch_page_revision(built_project, @target_page_title) do
      source_content = activity_revision.content
      rewired_id = target_revision.resource_id + 10_000

      page_map = %{
        Integer.to_string(target_revision.resource_id) => %{
          resource_id: rewired_id,
          slug: "rewired-target"
        }
      }

      {changed?, export_rewired} =
        RewireLinks.rewire(source_content, fn id -> "/course/link/rewired-#{id}" end, page_map)

      assert changed?

      export_iframe = fetch_iframe_part!(export_rewired)
      assert export_iframe["idref"] == rewired_id
      assert export_iframe["resource_id"] == rewired_id
      assert export_iframe["sourceType"] == "page"
      assert export_iframe["linkType"] == "page"

      ingest_content = %{
        "model" => [
          %{
            "type" => "content",
            "children" => [fetch_iframe_part!(source_content)]
          }
        ]
      }

      ingest_rewired =
        Rewiring.rewire_adaptive_link_references(ingest_content, %{
          target_revision.resource_id => rewired_id
        })

      [container] = ingest_rewired["model"]
      [ingest_iframe] = container["children"]

      assert ingest_iframe["idref"] == rewired_id
      assert ingest_iframe["resource_id"] == rewired_id

      state
    else
      {:error, reason} ->
        flunk("assert_iframe_rewiring_support failed: #{inspect(reason)}")
    end
  end

  def assert_iframe_section_resolution(%ExecutionState{} = state) do
    with {:ok, section} <- fetch_section(state, @section_name),
         {:ok, student} <- fetch_user(state, "iframe_student"),
         {:ok, built_project} <- fetch_project(state, @project_name),
         {:ok, activity_revision} <- fetch_delivery_activity_revision(state, section),
         {:ok, target_revision} <- fetch_page_revision(built_project, @target_page_title),
         {:ok, section_target_revision} <-
           fetch_section_revision(section.slug, target_revision.resource_id),
         {:ok, model} <-
           render_activity_model(
             section,
             student,
             built_project.project.slug,
             activity_revision,
             request_path: nil
           ) do
      iframe = fetch_iframe_part!(model)

      assert iframe["src"] ==
               "/sections/#{section.slug}/lesson/#{section_target_revision.slug}"

      refute Map.has_key?(iframe, "idref")
      refute Map.has_key?(iframe, "resource_id")

      state
    else
      {:error, reason} ->
        flunk("assert_iframe_section_resolution failed: #{inspect(reason)}")
    end
  end

  def retarget_iframe_to_outside_page(%ExecutionState{} = state) do
    with {:ok, built_project} <- fetch_project(state, @project_name),
         {:ok, outside_project} <- fetch_project(state, @outside_project_name),
         {:ok, outside_revision} <- fetch_page_revision(outside_project, @outside_page_title),
         {:ok, activity_revision} <- fetch_activity_revision(state),
         {:ok, updated_revision} <-
           update_iframe_target(
             built_project.project.slug,
             activity_revision,
             outside_revision
           ),
         {:ok, updated_state} <- update_activity_refs(state, updated_revision) do
      updated_state
    else
      {:error, reason} ->
        flunk("retarget_iframe_to_outside_page failed: #{inspect(reason)}")
    end
  end

  def assert_iframe_outside_fallback(%ExecutionState{} = state) do
    with {:ok, section} <- fetch_section(state, @section_name),
         {:ok, student} <- fetch_user(state, "iframe_student"),
         {:ok, built_project} <- fetch_project(state, @project_name),
         {:ok, source_revision} <- fetch_page_revision(built_project, @source_page_title),
         {:ok, section_source_revision} <-
           fetch_section_revision(section.slug, source_revision.resource_id),
         {:ok, activity_revision} <- fetch_delivery_activity_revision(state, section),
         {:ok, model} <-
           render_activity_model(
             section,
             student,
             built_project.project.slug,
             activity_revision,
             request_path: "/sections/#{section.slug}/lesson/#{section_source_revision.slug}"
           ) do
      iframe = fetch_iframe_part!(model)

      assert iframe["src"] == "about:blank"
      assert iframe["dynamicLinkFallback"]["type"] == "unresolved_internal_source"

      assert iframe["dynamicLinkFallback"]["href"] ==
               "/sections/#{section.slug}/lesson/#{section_source_revision.slug}"

      state
    else
      {:error, reason} ->
        flunk("assert_iframe_outside_fallback failed: #{inspect(reason)}")
    end
  end

  defp fetch_project(%ExecutionState{} = state, name) do
    case Engine.get_project(state, name) do
      nil -> {:error, {:project_not_found, name}}
      project -> {:ok, project}
    end
  end

  defp fetch_section(%ExecutionState{} = state, name) do
    case Engine.get_section(state, name) do
      nil -> {:error, {:section_not_found, name}}
      section -> {:ok, section}
    end
  end

  defp fetch_user(%ExecutionState{} = state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, {:user_not_found, name}}
      user -> {:ok, user}
    end
  end

  defp fetch_activity_revision(%ExecutionState{} = state) do
    case Map.get(state.activity_virtual_ids, {@project_name, @activity_virtual_id}) do
      nil -> {:error, :activity_not_found}
      revision -> {:ok, refresh_revision(revision)}
    end
  end

  defp fetch_delivery_activity_revision(%ExecutionState{} = state, section) do
    with {:ok, revision} <- fetch_activity_revision(state),
         {:ok, section_revision} <- fetch_section_revision(section.slug, revision.resource_id) do
      {:ok, section_revision}
    end
  end

  defp fetch_page_revision(built_project, title) do
    case Map.get(built_project.rev_by_title, title) do
      nil -> {:error, {:page_not_found, title}}
      revision -> {:ok, refresh_revision(revision)}
    end
  end

  defp fetch_section_revision(section_slug, resource_id) do
    case DeliveryResolver.from_resource_id(section_slug, resource_id) do
      nil -> {:error, {:section_revision_not_found, section_slug, resource_id}}
      revision -> {:ok, revision}
    end
  end

  defp refresh_revision(revision) do
    Resources.get_revision!(revision.id)
  end

  defp update_iframe_target(project_slug, activity_revision, target_revision) do
    source_json =
      Jason.encode!(%{
        "mode" => "page",
        "pageId" => target_revision.resource_id,
        "pageSlug" => target_revision.slug,
        "url" => ""
      })

    updated_content =
      deep_map(activity_revision.content, fn
        %{"type" => "janus-capi-iframe"} = iframe ->
          iframe
          |> Map.put("sourceType", "page")
          |> Map.put("linkType", "page")
          |> Map.put("idref", target_revision.resource_id)
          |> Map.put("resource_id", target_revision.resource_id)
          |> Map.put("sourcePageSlug", target_revision.slug)
          |> Map.put("src", "/course/link/#{target_revision.slug}")
          |> Map.put("source", source_json)

        other ->
          other
      end)

    case ChangeTracker.track_revision(project_slug, activity_revision, %{content: updated_content}) do
      {:ok, revision} -> {:ok, revision}
      error -> error
    end
  end

  defp update_activity_refs(%ExecutionState{} = state, revision) do
    activity_virtual_ids =
      Map.put(state.activity_virtual_ids, {@project_name, @activity_virtual_id}, revision)

    activities = Map.put(state.activities, {@project_name, @activity_title}, revision)

    {:ok, %{state | activity_virtual_ids: activity_virtual_ids, activities: activities}}
  end

  defp render_activity_model(
         section,
         user,
         project_slug,
         activity_revision,
         request_path: request_path
       ) do
    encoded_model = Jason.encode!(activity_revision.content) |> ActivityContext.encode()

    activity_map = %{
      activity_revision.resource_id => %ActivitySummary{
        id: activity_revision.resource_id,
        graded: false,
        state: "{ \"active\": true }",
        model: encoded_model,
        delivery_element: "oli-adaptive-delivery",
        authoring_element: "oli-adaptive-authoring",
        script: "./authoring-entry.ts",
        attempt_guid: "scenario-attempt",
        lifecycle_state: :active
      }
    }

    page_link_params =
      case request_path do
        nil -> nil
        value -> [request_path: value]
      end

    rendered_html =
      Activity.render(
        %Context{
          user: user,
          project_slug: project_slug,
          section_slug: section.slug,
          page_link_params: page_link_params,
          activity_map: activity_map,
          resource_summary_fn: fn resource_id ->
            case DeliveryResolver.from_resource_id(section.slug, resource_id) do
              nil -> nil
              revision -> %ResourceSummary{slug: revision.slug, title: revision.title}
            end
          end
        },
        %{"activity_id" => activity_revision.resource_id, "purpose" => "none"},
        Activity.Html
      )
      |> Phoenix.HTML.raw()
      |> Phoenix.HTML.safe_to_string()

    case Regex.run(~r/model="([^"]+)"/, rendered_html) do
      [_, model_json] ->
        case model_json |> HtmlEntities.decode() |> Jason.decode() do
          {:ok, model} -> {:ok, model}
          {:error, reason} -> {:error, {:invalid_model_json, reason}}
        end

      _ ->
        {:error, :missing_model_attribute}
    end
  end

  defp fetch_iframe_part!(%{"partsLayout" => parts_layout}) when is_list(parts_layout) do
    Enum.find(parts_layout, fn part -> part["type"] == "janus-capi-iframe" end) ||
      flunk("No janus-capi-iframe part found in rendered model")
  end

  defp fetch_iframe_part!(%{"authoring" => %{"parts" => parts}}) when is_list(parts) do
    Enum.find(parts, fn part -> part["type"] == "janus-capi-iframe" end) ||
      flunk("No janus-capi-iframe part found in authoring model")
  end

  defp fetch_iframe_part!(model),
    do: flunk("Unexpected adaptive model shape: #{inspect(model)}")

  defp deep_map(value, map_fn) when is_list(value) do
    Enum.map(value, &deep_map(&1, map_fn))
  end

  defp deep_map(value, map_fn) when is_map(value) do
    value
    |> Enum.reduce(%{}, fn {key, nested_value}, acc ->
      Map.put(acc, key, deep_map(nested_value, map_fn))
    end)
    |> map_fn.()
  end

  defp deep_map(value, _map_fn), do: value
end
