defmodule Oli.Rendering.Content.LearningObjectives do
  @moduledoc """
  Renders the delivery Learning Objectives page element from precomputed context data.
  """

  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.LearningObjectives.ProficiencyDisplay
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content.UrlHelpers
  alias OliWeb.Icons
  alias Phoenix.HTML
  alias Phoenix.HTML.Safe

  @page_type_id Oli.Resources.ResourceType.id_for_page()

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
      ~s|<section class="learning-objectives-element my-6 rounded-lg border border-Border-border-default bg-Surface-surface-primary p-6 shadow-sm">|,
      ~s|<h2 class="mb-4 font-open-sans text-2xl font-semibold leading-8 text-Text-text-high">Learning Objectives</h2>|,
      ~s|<div class="rounded-lg border border-Border-border-subtle bg-Surface-surface-primary p-3">|,
      render_objective_hierarchy(objectives, config, :introduction),
      "</div>",
      proficiency_explanation(),
      "</section>"
    ]
  end

  defp render_summary(%Context{} = context, objectives, config, opts) do
    resources_by_id = resolve_recommendation_pages(context, objectives, config, opts)

    [
      ~s|<section class="learning-objectives-element learning-objectives-summary my-6 rounded-lg border border-Border-border-default bg-Surface-surface-primary p-6 shadow-sm">|,
      ~s|<h2 class="mb-4 font-open-sans text-2xl font-semibold leading-8 text-Text-text-high">Learning Objective Summary</h2>|,
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
      ~s|<article class="learning-objective mb-2 rounded-lg border border-Border-border-subtle bg-Surface-surface-primary px-3 py-2 last:mb-0">|,
      ~s|<div class="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1">|,
      ~s|<span class="shrink-0 text-sm font-semibold uppercase text-Text-text-low-alpha">LO #{index}</span>|,
      ~s|<h3 class="m-0 min-w-0 flex-1 break-words text-base font-semibold leading-snug text-Text-text-high">#{escape(objective.title)}</h3>|,
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

    depth_class =
      if depth == 0,
        do: " bg-Surface-surface-primary",
        else: " bg-Surface-surface-secondary-muted md:ml-6"

    [
      ~s|<article class="learning-objective-summary#{depth_class} rounded-lg border border-Border-border-subtle p-4">|,
      ~s|<div class="flex min-w-0 flex-wrap items-start justify-between gap-3">|,
      ~s|<div class="min-w-0 flex-1">|,
      ~s|<div class="flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1">|,
      ~s|<span class="shrink-0 text-sm font-semibold uppercase text-Text-text-low-alpha">#{label}</span>|,
      ~s|<h3 class="m-0 min-w-0 flex-1 break-words text-base font-semibold leading-snug text-Text-text-high">#{escape(objective.title)}</h3>|,
      "</div>",
      "</div>",
      proficiency_badge(proficiency, objective.resource_id),
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
      ~s|<ul class="mt-2 ml-10 space-y-1 text-sm leading-relaxed text-Text-text-low">|,
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
      ~s|<h4 class="mb-1 text-sm font-semibold text-Text-text-low">#{label}</h4>|,
      ~s|<ul class="m-0 list-none space-y-1 p-0">|,
      Enum.map(pages, fn page ->
        href = lesson_href(context, page.slug)

        [
          ~s|<li class="min-w-0">|,
          ~s|<a class="internal-link flex min-h-11 items-center break-words py-2 text-Text-text-link underline" href="#{escape(href)}">|,
          escape(page.title),
          "</a>",
          "</li>"
        ]
      end),
      "</ul>",
      "</div>"
    ]
  end

  defp proficiency_badge(proficiency, objective_id) do
    display = proficiency_display(proficiency)

    [
      ~s|<div class="learning-objective-proficiency shrink-0">|,
      proficiency_icon(display, :summary, "summary_#{objective_id}"),
      "</div>"
    ]
  end

  defp proficiency_explanation do
    [
      ~s|<details class="group/proficiency learning-objectives-proficiency mt-4 px-1">|,
      ~s|<summary class="group flex h-[35px] cursor-pointer list-none items-center gap-1 border-b border-transparent text-Text-text-low-alpha group-open/proficiency:border-Border-border-subtle focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary [&::-webkit-details-marker]:hidden">|,
      ~s|<span class="inline-flex h-5 w-5 shrink-0 items-center justify-center text-Icon-icon-default">|,
      support_icon_component("h-5 w-5 text-Icon-icon-default"),
      "</span>",
      ~s|<span class="min-w-0 flex-1 font-open-sans text-xs font-semibold leading-3">What is proficiency and how is it estimated?</span>|,
      ~s|<span class="inline-flex h-4 w-4 shrink-0 items-center justify-center text-Icon-icon-default transition-transform group-open/proficiency:rotate-180">|,
      chevron_down_icon_component("h-4 w-4 text-Icon-icon-default"),
      "</span>",
      "</summary>",
      ~s|<div class="pb-3 pt-3">|,
      ~s|<p class="m-0 font-open-sans text-[14px] font-normal leading-6 text-Text-text-high">Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work. Proficiency estimates become more reliable as you complete more activities.</p>|,
      ~s|<div class="mt-[10px] grid grid-cols-2 gap-[6px] md:grid-cols-4">|,
      Enum.map(ProficiencyDisplay.levels(), &proficiency_explanation_card/1),
      "</div>",
      "</div>",
      "</details>"
    ]
  end

  defp proficiency_explanation_card(proficiency) do
    %{
      label_lines: label_lines,
      description: description,
      card_class: card_class,
      content_class: content_class,
      order_class: order_class
    } =
      display =
      proficiency_display(proficiency)

    label_html = Enum.join(label_lines, "<br/>")

    [
      ~s|<div class="flex h-[255px] min-w-0 flex-col items-center rounded-[9px] #{order_class} #{card_class} text-center font-open-sans">|,
      ~s|<div class="flex flex-col items-center gap-[15px] #{content_class}">|,
      ~s|<div class="flex h-6 items-center justify-center">|,
      proficiency_icon(display, :explanation, "explanation_#{display.id_key}"),
      "</div>",
      ~s|<div class="text-center text-[14px] font-bold leading-[17.5px] text-Text-text-high">#{label_html}</div>|,
      ~s|<p class="m-0 text-center text-[12px] font-normal leading-[15px] text-Text-text-high">#{description}</p>|,
      "</div>",
      "</div>"
    ]
  end

  defp proficiency_icon(%{label: label, icon: icon, icon_class: icon_class}, context, id_suffix) do
    wrapper_class =
      [
        "group relative inline-flex items-center justify-center rounded-md",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary",
        proficiency_icon_size_class(context)
      ]
      |> Enum.join(" ")

    [
      ~s|<span class="#{wrapper_class}" tabindex="0" role="img" aria-label="#{label}" title="#{label}">|,
      proficiency_icon_component(icon, icon_class, id_suffix),
      ~s|<span role="tooltip" class="pointer-events-none absolute bottom-full left-1/2 z-10 mb-2 -translate-x-1/2 whitespace-nowrap rounded bg-Specially-Tokens-Fill-fill-inverse px-2 py-1 text-xs font-semibold text-Specially-Tokens-Text-text-inverse opacity-0 shadow transition-opacity group-hover:opacity-100 group-focus:opacity-100">#{label}</span>|,
      "</span>"
    ]
  end

  defp proficiency_icon_size_class(:explanation), do: "h-6 w-6"
  defp proficiency_icon_size_class(_), do: "h-8 w-8"

  defp proficiency_icon_component(:empty_pot, class, id_suffix),
    do: component_to_iodata(Icons.proficiency_empty_pot(%{class: class, id_suffix: id_suffix}))

  defp proficiency_icon_component(:seed, class, _id_suffix),
    do: component_to_iodata(Icons.proficiency_seed(%{class: class}))

  defp proficiency_icon_component(:sprout, class, _id_suffix),
    do: component_to_iodata(Icons.proficiency_sprout(%{class: class}))

  defp proficiency_icon_component(:tree, class, _id_suffix),
    do: component_to_iodata(Icons.proficiency_tree(%{class: class}))

  defp support_icon_component(class) do
    component_to_iodata(
      Icons.support(%{
        class: class,
        width: "20",
        height: "20",
        view_box: "0 0 20 20",
        variant: "figma_20"
      })
    )
  end

  defp chevron_down_icon_component(class) do
    component_to_iodata(
      Icons.chevron_down(%{
        class: class,
        width: "16",
        height: "16",
        view_box: "0 0 16 16",
        variant: "stroke",
        path: "M4 7L8 11L12 7"
      })
    )
  end

  defp component_to_iodata(component), do: Safe.to_iodata(component)

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
    |> Map.get(objective_id, ProficiencyDisplay.default_label())
  end

  defp proficiency_display(proficiency) do
    proficiency
    |> ProficiencyDisplay.display_for()
    |> Map.merge(shared_card_styles_for(proficiency))
  end

  defp shared_card_styles_for("High") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Text-text-accent-green",
      card_class: "justify-start bg-Fill-Chip-Green px-[17px] pt-[25px]",
      content_class: "w-[126px]",
      order_class: "order-3 md:order-4"
    }
  end

  defp shared_card_styles_for("Medium") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-purple",
      card_class: "justify-start bg-Fill-Accent-fill-accent-purple px-[15px] pt-[28px]",
      content_class: "w-[130px]",
      order_class: "order-4 md:order-3"
    }
  end

  defp shared_card_styles_for("Low") do
    %{
      icon_class: "h-6 w-6 shrink-0 text-Icon-icon-accent-orange",
      card_class: "justify-start bg-Fill-Accent-fill-accent-orange/70 px-6 pt-[23px]",
      content_class: "w-[112px]",
      order_class: "order-2"
    }
  end

  defp shared_card_styles_for(_) do
    %{
      icon_class: "h-6 w-6 shrink-0",
      card_class:
        "justify-start bg-Fill-Chip-Gray px-4 pt-[31px] md:[html:not(.dark)_&]:bg-Table-table-row-1",
      content_class: "w-32",
      order_class: "order-1"
    }
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
