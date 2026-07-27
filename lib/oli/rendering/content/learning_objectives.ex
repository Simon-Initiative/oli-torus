defmodule Oli.Rendering.Content.LearningObjectives do
  @moduledoc """
  Renders the delivery Learning Objectives page element from precomputed context data.
  """

  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content.UrlHelpers
  alias Phoenix.HTML

  @page_type_id Oli.Resources.ResourceType.id_for_page()

  @default_proficiency "Not Enough Information"

  @spec render(%Context{}, map()) :: [any()]
  def render(%Context{} = context, element) do
    render(context, element, [])
  end

  @doc false
  def render(%Context{} = context, element, opts) do
    config = normalize_element(element)
    objectives = visible_objectives(context.learning_objectives, config)

    case objectives do
      [] ->
        []

      _ ->
        case config.mode do
          "summary" -> render_summary(context, objectives, config, opts)
          _ -> render_introduction(objectives, config)
        end
    end
  end

  @spec plaintext(%Context{}, map()) :: [any()]
  def plaintext(%Context{} = context, element) do
    config = normalize_element(element)

    context.learning_objectives
    |> visible_objectives(config)
    |> case do
      [] -> [""]
      objectives -> ["Learning Objectives: ", objective_titles_text(objectives)]
    end
  end

  @spec markdown(%Context{}, map()) :: [any()]
  def markdown(%Context{} = context, element) do
    config = normalize_element(element)

    context.learning_objectives
    |> visible_objectives(config)
    |> case do
      [] ->
        [""]

      objectives ->
        [
          "## ",
          heading(config),
          "\n\n",
          Enum.map(objectives, fn objective ->
            ["- ", objective.title, "\n"]
          end),
          "\n"
        ]
    end
  end

  defp render_introduction(objectives, config) do
    [
      ~s|<section class="learning-objectives-element my-6 rounded-lg border border-gray-200 bg-white p-5 shadow-sm">|,
      ~s|<h2 class="mb-4 text-2xl font-semibold text-gray-800">Learning Objectives</h2>|,
      ~s|<div class="rounded-lg border border-gray-200 bg-white p-3">|,
      render_objective_hierarchy(objectives, config, :introduction),
      "</div>",
      proficiency_explanation(),
      "</section>"
    ]
  end

  defp render_summary(%Context{} = context, objectives, config, opts) do
    resources_by_id = resolve_recommendation_pages(context, objectives, config, opts)

    [
      ~s|<section class="learning-objectives-element learning-objectives-summary my-6 rounded-lg border border-gray-200 bg-white p-5 shadow-sm">|,
      ~s|<h2 class="mb-4 text-2xl font-semibold text-gray-800">Learning Objective Summary</h2>|,
      ~s|<div class="space-y-3">|,
      render_objective_hierarchy(objectives, config, :summary, context, resources_by_id),
      "</div>",
      proficiency_explanation(),
      "</section>"
    ]
  end

  defp render_objective_hierarchy(objectives, config, _mode) do
    roots = root_objectives(objectives)
    objectives_by_id = Map.new(objectives, &{&1.resource_id, &1})

    Enum.with_index(roots, 1)
    |> Enum.map(fn {objective, index} ->
      render_introduction_objective(objective, index, objectives_by_id, config)
    end)
  end

  defp render_objective_hierarchy(objectives, config, :summary, context, resources_by_id) do
    roots = root_objectives(objectives)
    objectives_by_id = Map.new(objectives, &{&1.resource_id, &1})

    Enum.with_index(roots, 1)
    |> Enum.map(fn {objective, index} ->
      render_summary_objective(
        objective,
        "LO #{index}",
        objectives_by_id,
        config,
        context,
        resources_by_id,
        0
      )
    end)
  end

  defp render_introduction_objective(objective, index, objectives_by_id, config) do
    children = visible_children(objective, objectives_by_id)

    [
      ~s|<article class="learning-objective mb-2 rounded-lg border border-gray-200 bg-white px-3 py-2 last:mb-0">|,
      ~s|<div class="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1">|,
      ~s|<span class="shrink-0 text-sm font-semibold uppercase text-gray-500">LO #{index}</span>|,
      ~s|<h3 class="m-0 min-w-0 flex-1 break-words text-base font-semibold leading-snug text-gray-800">#{escape(objective.title)}</h3>|,
      "</div>",
      maybe_render_sub_objectives(children, config),
      "</article>"
    ]
  end

  defp render_summary_objective(
         objective,
         label,
         objectives_by_id,
         config,
         context,
         resources_by_id,
         depth
       ) do
    children = visible_children(objective, objectives_by_id)
    proficiency = proficiency_for(context.learning_objectives, objective.resource_id)
    config_row = Map.get(config.config_by_objective_id, objective.resource_id, %{})
    depth_class = if depth == 0, do: " bg-white", else: " bg-gray-50 md:ml-6"

    [
      ~s|<article class="learning-objective-summary#{depth_class} rounded-lg border border-gray-200 p-4">|,
      ~s|<div class="flex min-w-0 flex-wrap items-start justify-between gap-3">|,
      ~s|<div class="min-w-0 flex-1">|,
      ~s|<div class="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1">|,
      ~s|<span class="shrink-0 text-sm font-semibold uppercase text-gray-500">#{label}</span>|,
      ~s|<h3 class="m-0 min-w-0 flex-1 break-words text-base font-semibold leading-snug text-gray-800">#{escape(objective.title)}</h3>|,
      "</div>",
      "</div>",
      proficiency_badge(proficiency),
      "</div>",
      recommendations(context, config_row, resources_by_id),
      render_summary_children(
        children,
        objectives_by_id,
        config,
        context,
        resources_by_id,
        depth
      ),
      "</article>"
    ]
  end

  defp render_summary_children(
         [],
         _objectives_by_id,
         _config,
         _context,
         _resources_by_id,
         _depth
       ),
       do: []

  defp render_summary_children(
         children,
         objectives_by_id,
         config,
         context,
         resources_by_id,
         depth
       ) do
    [
      ~s|<div class="mt-3 space-y-3">|,
      Enum.map(children, fn child ->
        render_summary_objective(
          child,
          "Sub-Objective",
          objectives_by_id,
          config,
          context,
          resources_by_id,
          depth + 1
        )
      end),
      "</div>"
    ]
  end

  defp maybe_render_sub_objectives([], _config), do: []

  defp maybe_render_sub_objectives(children, %{include_sub_objectives?: true}) do
    [
      ~s|<ul class="mt-2 ml-10 space-y-1 text-sm leading-relaxed text-gray-700">|,
      Enum.map(children, fn child ->
        ~s|<li class="min-w-0 break-words">#{escape(child.title)}</li>|
      end),
      "</ul>"
    ]
  end

  defp maybe_render_sub_objectives(_children, _config), do: []

  defp recommendations(context, config_row, resources_by_id) do
    revisit_pages = resolved_recommendations(config_row, "revisit_pages", resources_by_id)
    practice_pages = resolved_recommendations(config_row, "practice_pages", resources_by_id)

    case {revisit_pages, practice_pages} do
      {[], []} ->
        []

      _ ->
        [
          ~s|<div class="mt-3 grid gap-3 md:grid-cols-2">|,
          recommendation_group(context, "Review", revisit_pages),
          recommendation_group(context, "Practice", practice_pages),
          "</div>"
        ]
    end
  end

  defp recommendation_group(_context, _label, []), do: []

  defp recommendation_group(context, label, pages) do
    [
      ~s|<div class="learning-objective-recommendations min-w-0">|,
      ~s|<h4 class="mb-1 text-sm font-semibold text-gray-700">#{label}</h4>|,
      ~s|<ul class="m-0 list-none space-y-1 p-0">|,
      Enum.map(pages, fn page ->
        href = lesson_href(context, page.slug)

        [
          ~s|<li class="min-w-0">|,
          ~s|<a class="internal-link flex min-h-11 items-center break-words py-2 text-blue-700 underline" href="#{escape(href)}">|,
          escape(page.title),
          "</a>",
          "</li>"
        ]
      end),
      "</ul>",
      "</div>"
    ]
  end

  defp proficiency_badge(proficiency) do
    %{label: label, icon: icon, class: class} = proficiency_display(proficiency)

    [
      ~s|<div class="learning-objective-proficiency #{class} shrink-0 rounded-lg px-3 py-2 text-sm font-semibold">|,
      ~s|<i class="#{icon} mr-1" aria-hidden="true"></i>|,
      ~s|<span>#{label}</span>|,
      "</div>"
    ]
  end

  defp proficiency_explanation do
    [
      ~s|<details class="learning-objectives-proficiency mt-4 border-t border-gray-200 pt-3">|,
      ~s|<summary class="min-h-11 cursor-pointer py-2 text-sm font-medium text-gray-600">|,
      ~s|<span class="inline-flex items-center gap-2">|,
      ~s|<i class="fas fa-info-circle" aria-hidden="true"></i>|,
      ~s|<span>What is proficiency and how is it estimated?</span>|,
      "</span>",
      "</summary>",
      ~s|<p class="mt-3 text-sm leading-relaxed text-gray-700">Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work.</p>|,
      ~s|<div class="mt-3 grid gap-2 sm:grid-cols-2 lg:grid-cols-4">|,
      proficiency_explanation_card(@default_proficiency),
      proficiency_explanation_card("Low"),
      proficiency_explanation_card("Medium"),
      proficiency_explanation_card("High"),
      "</div>",
      "</details>"
    ]
  end

  defp proficiency_explanation_card(proficiency) do
    %{label: label, icon: icon, description: description, class: class} =
      proficiency_display(proficiency)

    [
      ~s|<div class="rounded-lg #{class} p-3 text-center text-sm">|,
      ~s|<i class="#{icon} mb-2" aria-hidden="true"></i>|,
      ~s|<div class="font-semibold">#{label}</div>|,
      ~s|<p class="m-0 mt-2 leading-snug">#{description}</p>|,
      "</div>"
    ]
  end

  defp normalize_element(element) when is_map(element) do
    %{
      mode: normalize_mode(field(element, "mode")),
      include_sub_objectives?: field(element, "include_sub_objectives", true) != false,
      config_by_objective_id:
        element
        |> field("learning_objectives", [])
        |> List.wrap()
        |> Enum.reduce(%{}, fn config, acc ->
          case normalize_config(config) do
            nil -> acc
            normalized -> Map.put(acc, normalized.resource_id, normalized)
          end
        end)
    }
  end

  defp normalize_mode("summary"), do: "summary"
  defp normalize_mode(_), do: "introduction"

  defp normalize_config(config) when is_map(config) do
    case field(config, "resource_id") do
      resource_id when is_integer(resource_id) ->
        %{
          resource_id: resource_id,
          enabled?: field(config, "enabled", true) != false,
          revisit_pages: integer_list(field(config, "revisit_pages", [])),
          practice_pages: integer_list(field(config, "practice_pages", []))
        }

      _ ->
        nil
    end
  end

  defp normalize_config(_), do: nil

  defp visible_objectives(payload, _config) when is_nil(payload), do: []

  defp visible_objectives(payload, config) when is_map(payload) do
    objectives =
      payload
      |> field("objectives", [])
      |> List.wrap()

    objectives_by_id =
      payload
      |> field("objectives_by_id", %{})
      |> Enum.into(%{})

    objectives
    |> Enum.filter(&enabled_objective?(&1, objectives_by_id, config))
    |> Enum.map(&prune_children(&1, config))
  end

  defp enabled_objective?(
         %IncludedObjective{resource_id: resource_id} = objective,
         objectives_by_id,
         config
       ) do
    parent_ids = parent_resource_ids(objective)

    objective_enabled?(resource_id, config) &&
      include_objective_depth?(parent_ids, config) &&
      !disabled_ancestors?(parent_ids, objectives_by_id, config)
  end

  defp enabled_objective?(_objective, _objectives_by_id, _config), do: false

  defp include_objective_depth?([], _config), do: true
  defp include_objective_depth?(_parent_ids, %{include_sub_objectives?: true}), do: true
  defp include_objective_depth?(_parent_ids, _config), do: false

  defp disabled_ancestors?([], _objectives_by_id, _config), do: false

  defp disabled_ancestors?(parent_ids, objectives_by_id, config) do
    Enum.all?(parent_ids, &disabled_ancestor?(&1, objectives_by_id, config))
  end

  defp disabled_ancestor?(nil, _objectives_by_id, _config), do: false

  defp disabled_ancestor?(parent_id, objectives_by_id, config) do
    case Map.get(objectives_by_id, parent_id) do
      %IncludedObjective{} = parent ->
        !objective_enabled?(parent_id, config) ||
          disabled_ancestors?(parent_resource_ids(parent), objectives_by_id, config)

      _ ->
        false
    end
  end

  defp objective_enabled?(resource_id, config) do
    config.config_by_objective_id
    |> Map.get(resource_id, %{enabled?: true})
    |> Map.get(:enabled?, true)
  end

  defp prune_children(%IncludedObjective{} = objective, config) do
    children =
      if config.include_sub_objectives? do
        objective.children
      else
        []
      end

    %IncludedObjective{objective | children: children}
  end

  defp root_objectives(objectives) do
    visible_ids = MapSet.new(Enum.map(objectives, & &1.resource_id))

    Enum.filter(objectives, fn objective ->
      not Enum.any?(parent_resource_ids(objective), &MapSet.member?(visible_ids, &1))
    end)
  end

  defp parent_resource_ids(%IncludedObjective{parent_resource_ids: parent_ids})
       when is_list(parent_ids) and parent_ids != [],
       do: parent_ids

  defp parent_resource_ids(%IncludedObjective{parent_resource_id: nil}), do: []
  defp parent_resource_ids(%IncludedObjective{parent_resource_id: parent_id}), do: [parent_id]

  defp visible_children(%IncludedObjective{children: child_ids}, objectives_by_id) do
    child_ids
    |> Enum.map(&Map.get(objectives_by_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp proficiency_for(payload, objective_id) do
    payload
    |> field("performance_by_objective_id", %{})
    |> Map.get(objective_id, @default_proficiency)
  end

  # Keep analytics labels mapped in one place so student-facing copy can change without
  # touching metrics internals or individual render branches.
  defp proficiency_display(proficiency) do
    case proficiency do
      "High" ->
        %{
          label: "Strong Proficiency",
          icon: "fas fa-tree",
          class: "bg-green-100 text-green-800",
          description:
            "You are likely to successfully apply this learning objective in different contexts."
        }

      "Medium" ->
        %{
          label: "Growing Proficiency",
          icon: "fas fa-spa",
          class: "bg-fuchsia-100 text-fuchsia-800",
          description:
            "You have applied this learning objective and should keep practicing for consistency."
        }

      "Low" ->
        %{
          label: "Beginning Proficiency",
          icon: "fas fa-seedling",
          class: "bg-orange-100 text-orange-800",
          description: "You are beginning to learn how to apply this learning objective."
        }

      _ ->
        %{
          label: @default_proficiency,
          icon: "fas fa-hourglass-half",
          class: "bg-gray-100 text-gray-700",
          description: "Complete a few more activities before we can estimate your proficiency."
        }
    end
  end

  defp resolve_recommendation_pages(%Context{section_id: nil}, _objectives, _config, _opts),
    do: %{}

  defp resolve_recommendation_pages(%Context{section_id: section_id}, objectives, config, opts) do
    recommendation_ids =
      objectives
      |> Enum.flat_map(fn objective ->
        config.config_by_objective_id
        |> Map.get(objective.resource_id, %{})
        |> recommendation_ids()
      end)
      |> Enum.uniq()

    resolver =
      Keyword.get(
        opts,
        :recommendation_resources_fun,
        &SectionResourceDepot.get_resources_by_ids/2
      )

    # Recommendation IDs are advisory. Resolve them in one depot batch scoped to the current
    # section, then keep only page resources so stale or out-of-section references disappear.
    case recommendation_ids do
      [] ->
        %{}

      ids ->
        resolver.(section_id, ids)
        |> Enum.filter(&(&1.resource_type_id == @page_type_id))
        |> Map.new(&{&1.resource_id, &1})
    end
  end

  defp recommendation_ids(config_row) do
    integer_list(Map.get(config_row, :revisit_pages, [])) ++
      integer_list(Map.get(config_row, :practice_pages, []))
  end

  defp resolved_recommendations(config_row, key, resources_by_id) do
    config_row
    |> Map.get(field_atom(key), [])
    |> integer_list()
    |> Enum.map(&Map.get(resources_by_id, &1))
    |> Enum.reject(&is_nil/1)
  end

  defp lesson_href(%Context{internal_link_url: internal_link_url}, slug)
       when is_function(internal_link_url, 1),
       do: internal_link_url.(slug)

  defp lesson_href(%Context{section_slug: section_slug, page_link_params: page_link_params}, slug) do
    UrlHelpers.lesson_path(section_slug, slug, page_link_params)
  end

  defp heading(%{mode: "summary"}), do: "Learning Objective Summary"
  defp heading(_config), do: "Learning Objectives"

  defp objective_titles_text(objectives) do
    objectives
    |> Enum.map(& &1.title)
    |> Enum.join("; ")
  end

  defp integer_list(values) when is_list(values), do: Enum.filter(values, &is_integer/1)
  defp integer_list(_), do: []

  defp field(map, key, default \\ nil)

  defp field(map, key, default) when is_map(map) do
    atom_key = field_atom(key)

    cond do
      Map.has_key?(map, key) -> Map.get(map, key)
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp field(_map, _key, default), do: default

  defp field_atom("config_by_objective_id"), do: :config_by_objective_id
  defp field_atom("enabled"), do: :enabled
  defp field_atom("include_sub_objectives"), do: :include_sub_objectives
  defp field_atom("learning_objectives"), do: :learning_objectives
  defp field_atom("mode"), do: :mode
  defp field_atom("objectives"), do: :objectives
  defp field_atom("objectives_by_id"), do: :objectives_by_id
  defp field_atom("performance_by_objective_id"), do: :performance_by_objective_id
  defp field_atom("practice_pages"), do: :practice_pages
  defp field_atom("resource_id"), do: :resource_id
  defp field_atom("revisit_pages"), do: :revisit_pages
  defp field_atom(_), do: nil

  defp escape(value) do
    {:safe, escaped} = HTML.html_escape(to_string(value || ""))
    escaped
  end
end
