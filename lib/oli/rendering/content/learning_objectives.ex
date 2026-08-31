defmodule Oli.Rendering.Content.LearningObjectives do
  @moduledoc """
  Renders the delivery Learning Objectives page element from precomputed context data.
  """

  alias Oli.Delivery.LearningObjectives.IncludedObjective
  alias Oli.Delivery.LearningObjectives.ProficiencyDisplay
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content.UrlHelpers
  alias Phoenix.HTML

  @page_type_id Oli.Resources.ResourceType.id_for_page()
  @default_proficiency ProficiencyDisplay.default_label()

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
      ~s|<section class="learning-objectives-element my-6 rounded-[16px] border border-Border-border-default bg-Surface-surface-secondary p-4 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)] md:p-6">|,
      ~s|<h2 class="mb-4 font-open-sans text-[24px] font-medium leading-8 text-Text-text-high">Learning Objectives</h2>|,
      ~s|<div class="space-y-3">|,
      render_objective_hierarchy(objectives, config, :introduction),
      "</div>",
      proficiency_explanation(),
      "</section>"
    ]
  end

  defp render_summary(%Context{} = context, objectives, config, opts) do
    resources_by_id = resolve_recommendation_pages(context, objectives, config, opts)
    objectives_by_id = Map.new(objectives, &{&1.resource_id, &1})

    {applying_objectives, review_objectives} =
      objectives
      |> root_objectives()
      |> Enum.with_index(1)
      |> Enum.split_with(fn {objective, _index} ->
        objective
        |> then(&proficiency_for(context.learning_objectives, &1.resource_id))
        |> strong_proficiency?()
      end)

    [
      ~s|<section class="learning-objectives-element learning-objectives-summary my-6">|,
      ~s|<div class="learning-objectives-summary__sections">|,
      render_summary_section(
        :applying,
        "Learning Objectives You're Applying",
        applying_objectives,
        objectives_by_id,
        config,
        context,
        resources_by_id
      ),
      render_summary_section(
        :review,
        "Recommended Review",
        review_objectives,
        objectives_by_id,
        config,
        context,
        resources_by_id
      ),
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

  defp render_introduction_objective(objective, index, objectives_by_id, config) do
    children = visible_children(objective, objectives_by_id)

    [
      ~s|<article class="learning-objective rounded-[12px] border border-Border-border-default bg-Surface-surface-primary px-3 py-2 shadow-[0px_2px_10px_0px_rgba(0,50,99,0.05)]">|,
      ~s|<div class="learning-objectives-delivery__objective-copy">|,
      ~s|<div class="learning-objectives-delivery__objective-title-row">|,
      ~s|<span class="learning-objectives-delivery__objective-number">LO #{index}</span>|,
      ~s|<span class="learning-objectives-delivery__objective-title">#{escape(objective.title)}</span>|,
      "</div>",
      maybe_render_sub_objectives(children, config),
      "</div>",
      "</article>"
    ]
  end

  defp render_summary_section(
         _kind,
         _heading,
         [],
         _objectives_by_id,
         _config,
         _context,
         _resources_by_id
       ),
       do: []

  defp render_summary_section(
         kind,
         heading,
         objectives,
         objectives_by_id,
         config,
         context,
         resources_by_id
       ) do
    section_class = summary_section_class(kind)

    [
      ~s|<section class="learning-objectives-summary__section learning-objectives-summary__section--#{kind} #{section_class} border bg-Surface-surface-secondary">|,
      ~s|<h3 class="learning-objectives-summary__section-heading">|,
      summary_section_icon(kind),
      ~s|<span>#{heading}</span>|,
      "</h3>",
      ~s|<ul class="learning-objectives-summary__list">|,
      Enum.map(objectives, fn {objective, index} ->
        render_summary_objective(
          objective,
          index,
          kind,
          objectives_by_id,
          config,
          context,
          resources_by_id
        )
      end),
      "</ul>",
      "</section>"
    ]
  end

  defp render_summary_objective(
         objective,
         index,
         section_kind,
         objectives_by_id,
         config,
         context,
         resources_by_id
       ) do
    children = visible_children(objective, objectives_by_id)
    proficiency = proficiency_for(context.learning_objectives, objective.resource_id)
    config_row = Map.get(config.config_by_objective_id, objective.resource_id, %{})

    next_steps_content =
      summary_next_steps_content(section_kind, context, config_row, resources_by_id, objective)

    next_steps_attr = if next_steps_content == [], do: "", else: ~s| data-next-steps="available"|
    card_class = summary_card_class(section_kind, proficiency)
    card_header = summary_objective_header(objective, index, children, config, proficiency)

    [
      ~s|<li class="learning-objectives-summary__item">|,
      ~s|<article class="learning-objectives-summary__card #{card_class} border bg-Surface-surface-primary"#{next_steps_attr}>|,
      summary_objective_content(card_header, next_steps_content, index),
      "</article>",
      "</li>"
    ]
  end

  defp summary_objective_header(objective, index, children, config, proficiency) do
    [
      ~s|<div class="learning-objectives-summary__card-header">|,
      ~s|<div class="learning-objectives-delivery__objective-copy">|,
      ~s|<div class="learning-objectives-delivery__objective-title-row">|,
      ~s|<span class="learning-objectives-delivery__objective-number">LO #{index}</span>|,
      ~s|<span class="learning-objectives-delivery__objective-title">#{escape(objective.title)}</span>|,
      "</div>",
      maybe_render_sub_objectives(children, config),
      "</div>",
      proficiency_badge(proficiency),
      "</div>"
    ]
  end

  defp summary_objective_content(card_header, [], _index), do: card_header

  defp summary_objective_content(card_header, next_steps_content, index) do
    [
      ~s|<details class="learning-objectives-summary__next-steps">|,
      ~s|<summary class="learning-objectives-summary__next-steps-summary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus">|,
      ~s|<span class="learning-objectives-summary__next-steps-header">|,
      card_header,
      ~s|<span class="learning-objectives-summary__next-steps-trigger text-Text-text-button">|,
      ~s|<span class="learning-objectives-summary__next-steps-label">|,
      ~s|<span class="learning-objectives-summary__next-steps-show">Show next steps</span>|,
      ~s|<span class="learning-objectives-summary__next-steps-hide">Hide next steps</span>|,
      ~s|<span class="sr-only"> for LO #{index}</span>|,
      "</span>",
      "</span>",
      "</span>",
      "</summary>",
      ~s|<div class="learning-objectives-summary__next-steps-content">|,
      next_steps_content,
      "</div>",
      "</details>"
    ]
  end

  defp maybe_render_sub_objectives([], _config), do: []

  defp maybe_render_sub_objectives(children, %{include_sub_objectives?: true}) do
    [
      ~s|<ul class="learning-objectives-delivery__sub-objective-list">|,
      Enum.map(children, fn child ->
        ~s|<li class="learning-objectives-delivery__sub-objective">#{escape(child.title)}</li>|
      end),
      "</ul>"
    ]
  end

  defp maybe_render_sub_objectives(_children, _config), do: []

  defp proficiency_badge(proficiency) do
    %{label: label, icon: icon, class: class} = proficiency_badge_display(proficiency)

    [
      ~s|<div class="learning-objectives-summary__proficiency learning-objectives-summary__proficiency--#{class}" aria-label="#{label}">|,
      icon,
      ~s|<span>#{label}</span>|,
      "</div>"
    ]
  end

  defp summary_next_steps_content(:review, context, config_row, resources_by_id, objective) do
    revisit_pages = resolved_recommendations(config_row, "revisit_pages", resources_by_id)
    practice_pages = resolved_recommendations(config_row, "practice_pages", resources_by_id)

    case {revisit_pages, practice_pages} do
      {[], []} ->
        []

      _ ->
        [
          recommendation_group(context, "REVISIT", :revisit, revisit_pages),
          recommendation_group(context, "PRACTICE", :practice, practice_pages),
          maybe_dot_explain_card(context, objective)
        ]
    end
  end

  defp summary_next_steps_content(_section_kind, _context, _config_row, _resources_by_id, _objective),
    do: []

  defp maybe_dot_explain_card(%Context{assistant_available?: true} = context, objective) do
    [
      ~s|<section class="learning-objectives-summary__explain-card border border-Border-border-subtle bg-Surface-surface-secondary-hover" aria-label="Ask DOT to explain this objective">|,
      ~s|<div class="w-[72px] h-[72px] relative shrink-0" aria-hidden="true">|,
      ~s|<img class="animate-[spin_40s_cubic-bezier(0.4,0,0.6,1)_infinite]" src="/images/assistant/footer_dot_ai.png" alt="" />|,
      ~s|<div class="w-[28px] h-[28px] absolute inset-0 m-auto bg-zinc-300 rounded-full blur-[16px] animate-[pulse_6s_cubic-bezier(0.4,0,0.6,1)_infinite]"></div>|,
      ~s|</div>|,
      ~s|<span class="learning-objectives-summary__explain-copy">|,
      ~s|<strong>Need help understanding this objective?</strong>|,
      ~s|<span>Ask our AI Learning Assistant, DOT, to explain.</span>|,
      "</span>",
      ~s|<button type="button" id="explain-lo-#{objective.resource_id}" class="learning-objectives-summary__explain-button" phx-hook="ExplainObjectiveButton" data-section-slug="#{context.section_slug}" data-resource-id="#{context.page_id}" data-objective-title="#{escape(objective.title)}" aria-label="Explain this learning objective with DOT">Explain</button>|,
      "</section>"
    ]
  end

  defp maybe_dot_explain_card(_context, _objective), do: []

  defp recommendation_group(_context, _heading, _kind, []), do: []

  defp recommendation_group(context, heading, kind, pages) do
    [
      ~s|<section class="learning-objectives-summary__recommendation-group learning-objectives-summary__recommendation-group--#{kind}">|,
      ~s|<h4 class="learning-objectives-summary__recommendation-heading text-Text-text-low-alpha">|,
      recommendation_group_icon(kind),
      ~s|<span>#{heading}</span>|,
      "</h4>",
      ~s|<ul class="learning-objectives-summary__recommendation-list">|,
      Enum.map(pages, &recommendation_link(context, &1)),
      "</ul>",
      "</section>"
    ]
  end

  defp recommendation_link(context, page) do
    href =
      context
      |> lesson_href(page_navigation_slug(page))
      |> escape()

    [
      ~s|<li class="learning-objectives-summary__recommendation-item">|,
      ~s|<a class="learning-objectives-summary__recommendation-link internal-link text-Text-text-button" href="#{href}">|,
      ~s|<span>#{escape(page.title)}</span>|,
      "</a>",
      "</li>"
    ]
  end

  defp lesson_href(%Context{internal_link_url: internal_link_url}, slug)
       when is_function(internal_link_url, 1),
       do: internal_link_url.(slug)

  defp lesson_href(%Context{section_slug: section_slug, page_link_params: page_link_params}, slug) do
    UrlHelpers.lesson_path(section_slug, slug, page_link_params)
  end

  defp page_navigation_slug(%{revision_slug: revision_slug}) when is_binary(revision_slug),
    do: revision_slug

  defp page_navigation_slug(%{slug: slug}), do: slug

  defp recommendation_group_icon(:revisit) do
    ~S|<span class="learning-objectives-summary__recommendation-heading-icon" aria-hidden="true"><svg width="20" height="20" viewBox="0 0 20 20" focusable="false" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4.16602 15.0007C4.16602 15.4427 4.34161 15.8666 4.65417 16.1792C4.96673 16.4917 5.39065 16.6673 5.83268 16.6673H15.8327V3.33398H5.83268C5.39065 3.33398 4.96673 3.50958 4.65417 3.82214C4.34161 4.1347 4.16602 4.55862 4.16602 5.00065V15.0007ZM4.16602 15.0007C4.16602 14.5586 4.34161 14.1347 4.65417 13.8221C4.96673 13.5096 5.39065 13.334 5.83268 13.334H15.8327M7.49935 6.66732H12.4993" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg></span>|
  end

  defp recommendation_group_icon(:practice) do
    ~S|<span class="learning-objectives-summary__recommendation-heading-icon" aria-hidden="true"><svg width="20" height="20" viewBox="0 0 20 20" focusable="false" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7.49984 4.16667H5.83317C5.39114 4.16667 4.96722 4.34226 4.65466 4.65482C4.3421 4.96738 4.1665 5.39131 4.1665 5.83333V15.8333C4.1665 16.2754 4.3421 16.6993 4.65466 17.0118C4.96722 17.3244 5.39114 17.5 5.83317 17.5H14.1665C14.6085 17.5 15.0325 17.3244 15.345 17.0118C15.6576 16.6993 15.8332 16.2754 15.8332 15.8333V5.83333C15.8332 5.39131 15.6576 4.96738 15.345 4.65482C15.0325 4.34226 14.6085 4.16667 14.1665 4.16667H12.4998M7.49984 4.16667C7.49984 3.72464 7.67543 3.30072 7.98799 2.98816C8.30055 2.67559 8.72448 2.5 9.1665 2.5H10.8332C11.2752 2.5 11.6991 2.67559 12.0117 2.98816C12.3242 3.30072 12.4998 3.72464 12.4998 4.16667M7.49984 4.16667C7.49984 4.60869 7.67543 5.03262 7.98799 5.34518C8.30055 5.65774 8.72448 5.83333 9.1665 5.83333H10.8332C11.2752 5.83333 11.6991 5.65774 12.0117 5.34518C12.3242 5.03262 12.4998 4.60869 12.4998 4.16667M7.49984 10H7.50817M10.8332 10H12.4998M7.49984 13.3333H7.50817M10.8332 13.3333H12.4998" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg></span>|
  end

  defp summary_card_class(:review, "Low"),
    do:
      "learning-objectives-summary__card--review-beginning border-Fill-Accent-fill-accent-orange-bold"

  defp summary_card_class(:review, "Medium"),
    do:
      "learning-objectives-summary__card--review-growing border-Fill-Accent-fill-accent-purple-bold"

  defp summary_card_class(:review, _proficiency),
    do: "learning-objectives-summary__card--review-unknown border-Text-text-low-alpha"

  defp summary_card_class(_section_kind, _proficiency), do: "border-Border-border-default"

  defp summary_section_class(:applying), do: "border-Text-text-accent-green"
  defp summary_section_class(_kind), do: "border-Border-border-subtle"

  defp summary_section_icon(:applying) do
    ~S|<span class="learning-objectives-summary__section-icon learning-objectives-summary__section-icon--applying" aria-hidden="true"><svg width="24" height="24" viewBox="0 0 24 24" focusable="false" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M4.5 12L9.5 17L19.5 7" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></span>|
  end

  defp summary_section_icon(:review) do
    ~S|<span class="learning-objectives-summary__section-icon learning-objectives-summary__section-icon--review" aria-hidden="true"><svg width="16" height="16" viewBox="0 0 16 16" focusable="false" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M1.26801 10.0428C1.70497 11.4659 2.58322 12.7132 3.77577 13.6043C4.96833 14.4954 6.41339 14.9841 7.90201 14.9998C9.62399 15.0211 11.2936 14.4079 12.5925 13.2772C13.8914 12.1465 14.7288 10.5773 14.945 8.86881C15.1578 7.16033 14.7334 5.43336 13.7531 4.01803C12.7728 2.6027 11.3052 1.5983 9.63101 1.19681C7.95642 0.791753 6.19135 1.01656 4.67176 1.82845C3.15217 2.64033 1.98414 3.98262 1.39001 5.59981M1 1.99982V5.99982H5" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg></span>|
  end

  defp proficiency_badge_display("High") do
    %{
      label: "Strong Proficiency",
      icon: large_tree_icon(""),
      class: "strong"
    }
  end

  defp proficiency_badge_display("Medium") do
    %{
      label: "Growing Proficiency",
      icon: sprout_icon(""),
      class: "growing"
    }
  end

  defp proficiency_badge_display("Low") do
    %{
      label: "Beginning Proficiency",
      icon: almond_icon(""),
      class: "beginning"
    }
  end

  defp proficiency_badge_display(_proficiency) do
    %{
      label: @default_proficiency,
      icon: potted_plant_icon(),
      class: "unknown"
    }
  end

  defp proficiency_explanation do
    [
      ~s|<details class="learning-objectives-editor__proficiency learning-objectives-proficiency">|,
      ~s|<summary class="learning-objectives-editor__proficiency-summary focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus">|,
      ~s|<span class="learning-objectives-editor__proficiency-title">|,
      proficiency_info_icon(),
      ~s|<span>What is proficiency and how is it estimated?</span>|,
      "</span>",
      chevron_down_icon(),
      "</summary>",
      ~s|<p class="learning-objectives-editor__proficiency-description">Proficiency is our best estimate of how likely you are to successfully apply a learning objective the next time you use it. It updates as you complete course activities and is based on evidence from your overall work. Proficiency estimates become more reliable as you complete more activities.</p>|,
      ~s|<div class="learning-objectives-editor__proficiency-cards">|,
      proficiency_explanation_card(@default_proficiency),
      proficiency_explanation_card("Low"),
      proficiency_explanation_card("Medium"),
      proficiency_explanation_card("High"),
      "</div>",
      "</details>"
    ]
  end

  defp proficiency_explanation_card(proficiency) do
    %{label: label, description: description, card_class: card_class, icon: icon} =
      proficiency_explanation_display(proficiency)

    [
      ~s|<div class="learning-objectives-editor__proficiency-card #{card_class}">|,
      icon,
      ~s|<strong>#{label}</strong>|,
      ~s|<span>#{description}</span>|,
      "</div>"
    ]
  end

  defp proficiency_explanation_display("High") do
    %{
      label: "Strong Proficiency",
      icon: large_tree_icon(""),
      card_class: "learning-objectives-editor__proficiency-card--strong",
      description:
        "You are likely to successfully apply this learning objective in different contexts. Continue applying this learning objective as you progress through the course."
    }
  end

  defp proficiency_explanation_display("Medium") do
    %{
      label: "Growing Proficiency",
      icon: sprout_icon(""),
      card_class: "learning-objectives-editor__proficiency-card--growing",
      description:
        "You've clearly applied this learning objective. Continue practicing across more opportunities to strengthen your consistency."
    }
  end

  defp proficiency_explanation_display("Low") do
    %{
      label: "Beginning Proficiency",
      icon: almond_icon(""),
      card_class: "learning-objectives-editor__proficiency-card--beginning",
      description:
        "You are beginning to learn how to apply this learning objective. Continue practicing and reviewing feedback to strengthen your proficiency."
    }
  end

  defp proficiency_explanation_display(_) do
    %{
      label: @default_proficiency,
      icon: potted_plant_icon(),
      card_class: "learning-objectives-editor__proficiency-card--unknown",
      description: "Complete a few more activities before we can estimate your proficiency."
    }
  end

  defp proficiency_info_icon do
    ~s|<i class="fas fa-info-circle shrink-0" aria-hidden="true"></i>|
  end

  defp chevron_down_icon do
    ~s|<i class="fas fa-chevron-down" aria-hidden="true"></i>|
  end

  defp potted_plant_icon do
    ~S"""
    <svg class="" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" focusable="false"><rect width="24" height="24" fill="url(#potted-plant-pattern)"></rect><use href="#potted-plant-image" xlink:href="#potted-plant-image" transform="matrix(0.5 0 0 0.75 -10.5 -38.25)"></use><defs><pattern id="potted-plant-pattern" patternContentUnits="objectBoundingBox" width="1" height="1"><use href="#potted-plant-image" xlink:href="#potted-plant-image" transform="matrix(0.0208333 0 0 0.03125 -0.4375 -1.59375)"></use></pattern><image id="potted-plant-image" width="90" height="90" preserveAspectRatio="none" href="data:image/png;base64,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" xlink:href="data:image/png;base64,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"></image></defs></svg>
    """
  end

  defp almond_icon(class) do
    ~s|<svg class="h-6 w-6 shrink-0 #{class}" aria-hidden="true" focusable="false" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M19.3202 3.1975C19.5787 3.18173 20.0779 3.14788 20.3112 3.22923C20.4818 3.28872 20.7073 3.50402 20.7717 3.67675C20.7924 3.73239 20.8231 3.84585 20.8205 3.90353C20.7964 4.4425 20.8575 7.6446 20.7568 7.88317C20.6954 7.91704 20.7118 7.906 20.6246 7.88409C20.5396 7.9093 20.5341 8.61318 20.531 8.73159C20.5164 9.29268 20.3941 9.23582 20.2619 9.6655C20.2143 9.82056 20.2161 9.99531 20.1872 10.1554C20.1352 10.4436 19.9622 10.7481 19.8423 11.0183C19.3843 12.0505 18.9062 13.0807 18.3009 14.0373C18.0912 14.3688 17.8036 14.687 17.5623 14.9992C17.3847 15.229 17.2311 15.4778 17.0502 15.7041C16.938 15.8444 16.8101 15.9717 16.696 16.1104C16.5855 16.2447 16.4871 16.3924 16.3687 16.5198C16.2491 16.6484 16.1138 16.7621 15.9954 16.8921C15.4244 17.5191 14.8521 18.1106 14.2112 18.6687C14.0386 18.819 13.8665 18.9834 13.6815 19.1174C13.545 19.2164 13.3836 19.284 13.2404 19.3743C12.8698 19.6078 12.4945 19.8528 12.1061 20.0559C11.6604 20.289 10.8954 20.563 10.4008 20.673C8.65781 21.0602 7.32018 20.7321 5.83514 19.7856C5.67236 19.6802 5.34335 19.4109 5.19651 19.2788C4.29119 18.4715 3.73903 17.5204 3.38025 16.3716C3.14454 15.617 3.13148 14.9369 3.22146 14.1502C3.2647 13.772 3.4499 13.2535 3.5666 12.89C3.73898 12.3531 3.95369 11.8237 4.25557 11.3467C4.68079 10.603 5.14872 9.95057 5.7419 9.32915C6.13228 8.92021 6.55022 8.53619 6.96096 8.1479C7.75331 7.38259 8.62232 6.6918 9.5223 6.05959C10.0132 5.71476 10.436 5.40203 10.9874 5.14419C11.2004 5.03809 11.4184 4.87171 11.6347 4.77721C12.2141 4.52416 12.8013 4.24356 13.386 4.00715C13.8012 3.83924 14.304 3.77221 14.743 3.70663C14.9112 3.68151 15.1268 3.54327 15.3061 3.52127C15.7347 3.4633 16.1676 3.45639 16.598 3.41294C16.9325 3.41894 17.3273 3.27848 17.6451 3.27048C18.2011 3.25649 18.7663 3.23106 19.3202 3.1975ZM7.52524 17.7752C7.64074 18.0176 7.69713 18.1074 7.91013 18.2854C8.28595 18.5725 9.57368 18.4032 10.0422 18.394C10.2801 18.3892 10.6885 18.2322 10.9212 18.1643C13.1208 17.4854 14.4556 15.5624 15.7222 13.7791C16.3019 12.9629 16.7803 12.1124 17.1235 11.1702C17.185 11.0004 17.4762 10.3231 17.1592 10.2787C16.6397 10.6804 16.0693 11.7037 15.6311 12.2964C14.3041 14.0942 12.7992 15.9211 10.6227 16.6852C10.3146 16.7934 9.69719 16.8334 9.36293 16.8674C8.5189 16.9532 7.79039 16.6802 7.52524 17.7752ZM6.33721 12.3971C6.46739 12.7655 6.72754 13.1121 7.16814 12.9387C7.20923 12.9227 7.24933 12.9043 7.28826 12.8837C7.53079 12.6696 7.63537 12.4022 7.80616 12.1323C8.10902 11.6535 8.39456 11.3297 8.84327 10.9869C9.65282 10.3686 10.763 10.2318 11.6375 9.69843C11.9421 9.51264 12.0996 9.22492 12.3158 8.95284C12.7526 8.40323 13.0959 7.80168 13.6287 7.33661C13.9874 7.02351 14.2813 6.9037 14.7097 6.70811C14.8274 6.65437 15.1539 6.57609 15.2058 6.52016C15.173 6.20964 14.4281 6.1768 14.1909 6.19431C14.0417 6.2298 13.7963 6.28417 13.6597 6.33534C12.9885 6.58675 12.4557 7.17109 11.9839 7.69316C11.6167 8.09941 11.5704 8.17797 11.1318 8.47694C10.6041 8.83661 10.3546 8.85953 9.77758 9.05552C8.8312 9.37696 8.12032 9.7529 7.44886 10.5039C7.21706 10.7632 7.04142 10.9014 6.85272 11.2167C6.58164 11.6696 6.45839 11.8821 6.33721 12.3971Z" fill="currentColor"/></svg>|
  end

  defp sprout_icon(class) do
    ~s|<svg class="h-6 w-6 shrink-0 #{class}" aria-hidden="true" focusable="false" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M21.2889 2.38012C21.4036 2.37652 21.5275 2.36592 21.6428 2.3584C21.6134 2.67586 21.6315 3.06431 21.6299 3.38648C21.624 4.59009 21.7105 5.53875 21.4162 6.71707C21.0398 8.22415 20.5116 9.58523 19.3168 10.6451C18.4907 11.3779 17.5598 11.8446 16.4619 11.9862C16.2738 12.0087 15.2978 12.0398 15.1874 11.9468C15.0782 11.6186 15.558 10.8106 15.7066 10.488C15.77 10.3503 15.8869 10.0619 15.9651 9.94896C16.2389 9.55418 16.5212 9.16838 16.7825 8.76373C17.1394 8.26685 17.6479 7.86513 17.9727 7.33973C18.0752 7.20616 18.0801 7.10198 18.1015 6.94352C18.1517 6.57037 17.6646 6.24253 17.3184 6.24337C16.6609 6.24499 16.4354 6.98309 16.0104 7.33448C15.931 7.40011 15.81 7.62764 15.734 7.71197C15.5023 8.0224 15.2652 8.32439 15.0674 8.6573C14.7556 9.12408 14.484 9.52741 14.2258 10.0297C14.1072 10.238 14.041 10.4947 13.9397 10.7074C13.531 11.5652 13.3 12.3807 13.0999 13.3017C12.9442 14.0182 12.7799 14.4228 12.8118 15.1916C12.3966 15.188 11.5823 15.1695 11.1951 15.2064C11.202 14.8519 11.1938 14.5641 11.1514 14.212C11.1008 13.791 10.9744 13.4768 10.8476 13.0779C10.7872 12.8879 10.7665 12.6424 10.6966 12.4605C10.3946 11.6745 9.86137 10.8981 9.32669 10.2473C9.17151 10.0659 8.97597 9.91746 8.80935 9.74899C8.23122 9.16441 7.61078 8.63759 6.98181 8.10973C6.79865 7.956 6.63534 7.78111 6.44385 7.62759C6.06545 7.32422 5.55655 7.33884 5.26305 7.75022C5.1648 7.89213 5.09226 8.09824 5.12242 8.27932C5.30104 8.9332 6.26106 9.46509 6.70694 9.99232C7.15159 10.5181 7.5535 11.028 7.97547 11.5725C7.97193 11.7055 7.97601 11.8285 7.98018 11.961C7.78553 11.9793 7.59041 11.9919 7.39504 11.999C6.07567 12.0453 5.00388 11.5986 4.09654 10.6533C3.66991 10.2087 3.28905 9.64868 3.00564 9.09926C2.92328 8.93958 2.89047 8.7154 2.81999 8.54843C2.76482 8.403 2.66746 8.2065 2.6256 8.06813C2.58941 7.9485 2.59202 7.66643 2.55604 7.52538C2.50195 7.31332 2.41061 7.14663 2.39652 6.92602C2.33365 5.94202 2.39268 4.93486 2.35938 3.9498C2.63882 3.996 3.25898 3.9813 3.56636 3.98109L5.09987 3.98079C5.63158 3.9843 6.03555 3.97153 6.53983 4.14598C6.68641 4.1967 6.96977 4.23026 7.1354 4.27214C8.67386 4.67916 9.65409 5.66224 10.1785 7.14209C10.4435 7.89 10.3782 8.19073 10.4586 8.90393C10.4766 9.06413 11.2425 10.0172 11.3859 10.2582C11.5434 10.5228 11.7186 10.9199 11.8704 11.1929C12.1383 10.7975 12.4605 10.3364 12.2685 9.85437C12.0674 9.34962 12.0028 9.02257 12.003 8.47854C12.0033 7.95509 11.9736 7.39798 12.0685 6.87724C12.1134 6.63045 12.2158 6.37997 12.2712 6.13418C12.374 5.56275 12.6306 5.18292 12.9749 4.73154C13.1006 4.5667 13.2643 4.2904 13.4121 4.14769C14.1502 3.43516 15.061 2.99255 16.0395 2.71003C16.2043 2.66025 16.3932 2.64663 16.5571 2.59845C17.3616 2.36196 18.1246 2.38659 18.9579 2.38676C19.7349 2.39177 20.512 2.38957 21.2889 2.38012Z" fill="currentColor"/><path d="M11.4455 16.7912C12.3389 16.738 13.05 16.7796 13.8784 17.161C14.1406 17.2818 14.4356 17.4976 14.7146 17.5564C15.0055 17.6177 15.3828 17.5548 15.6828 17.5848C15.8971 17.6089 16.35 17.7524 16.5684 17.8188C16.8828 17.9144 17.2977 18.2969 17.5975 18.4174C17.7745 18.4593 18.0638 18.4415 18.2428 18.4261C20.1451 18.2626 21.531 19.8005 21.6444 21.6347C21.3582 21.6024 20.8133 21.6144 20.5124 21.6141L18.5131 21.6137L12.0346 21.614L5.49603 21.6137L3.51654 21.6133C3.19536 21.6133 2.67106 21.5981 2.37247 21.637C2.31121 19.477 4.30944 17.4903 6.47722 17.5734C6.87683 17.5347 7.54948 17.6929 7.9028 17.8755C8.8422 18.3612 8.56308 18.1406 9.23201 17.6322C9.73337 17.2511 10.8033 16.8283 11.4455 16.7912Z" fill="currentColor"/></svg>|
  end

  defp large_tree_icon(class) do
    ~s|<svg class="h-6 w-6 shrink-0 #{class}" aria-hidden="true" focusable="false" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M11.5656 2.39976C12.7984 2.27416 13.0263 2.89373 14.1373 3.14676C14.5336 3.23702 15.1458 3.11754 15.5345 3.25715C16.047 3.45068 15.9468 4.1126 16.1423 4.53162C16.7609 5.85733 17.8257 5.47549 18.9929 5.64016C19.2375 5.67469 19.5215 5.80251 19.7638 5.89394C20.0561 6.2381 20.1466 6.6127 19.7855 6.96272C18.4461 8.26099 16.4562 8.02108 14.7514 7.9755C14.2437 7.93594 13.7025 7.8926 13.2348 7.68077C12.6346 7.40885 12.8252 7.19976 12.7744 6.67287C12.7045 5.94752 12.4275 5.38901 11.593 5.70047C11.3187 5.91387 10.9852 6.22671 10.6435 6.33075C10.3578 6.4177 9.913 6.3419 9.64762 6.19458C9.63463 6.39609 9.6287 6.64865 9.51313 6.82209C9.2901 7.15718 8.74837 7.18708 8.38171 7.20687C7.77597 7.23954 7.20681 7.18434 6.60637 7.31177C6.53573 7.4654 6.38202 7.86534 6.25745 7.93216C5.88229 8.08404 5.22649 8.01609 4.84755 7.95914C3.88263 7.81408 3.00381 7.16747 3.21536 6.08191C3.27318 5.78519 3.95303 5.41134 4.18928 5.2338C4.49568 5.00353 4.79413 4.73576 5.11987 4.52648C5.46909 4.51561 5.98448 4.45005 6.35481 4.45704C6.38132 4.45753 6.62774 4.05769 6.68685 3.98641C6.88436 3.74833 7.15356 3.57865 7.42682 3.43666C8.25993 2.99716 9.1101 3.30855 10.0373 3.06567C10.7443 2.88044 10.8559 2.56917 11.5656 2.39976Z" fill="currentColor"/><path d="M11.036 7.7818C11.3468 7.8272 11.5238 8.18178 11.6682 8.42858C11.7454 8.56058 11.8983 8.80494 11.9426 8.94411C12.3667 10.2765 12.4431 10.314 13.4171 9.36385C13.6339 9.37377 14.5961 9.46965 14.6506 9.68553C14.6035 9.83122 14.086 10.6975 13.9755 10.7987L13.9633 10.8098C13.8041 10.9559 13.6147 11.0082 13.4558 11.1322C12.762 11.6519 12.4817 11.9836 12.1719 12.7787C11.6157 14.206 12.6718 15.563 14.0813 15.9707C14.5203 16.4723 14.5353 16.2999 14.1445 16.9319C14.0718 17.0493 14.0186 17.211 13.9507 17.3316C13.5493 18.0445 13.6001 18.7382 13.6013 19.5187L13.6021 21.6352C13.3779 21.6028 12.9294 21.6118 12.6883 21.6117L11.1622 21.6125C10.9366 21.6122 10.6192 21.6026 10.4029 21.6324C10.3976 20.9108 10.3975 20.1891 10.4025 19.4674C10.4032 19.1518 10.4149 18.6948 10.3918 18.3915C10.3632 18.0155 10.1302 17.4066 9.95767 17.0656C9.83036 16.8455 9.73019 16.5541 9.58722 16.3469C8.96401 15.4436 8.25065 14.6098 7.46964 13.8397C7.42445 13.7951 7.40711 13.7495 7.40826 13.6871C7.4991 13.5717 8.62117 13.2458 8.92028 13.0955C9.28515 13.3287 9.6014 13.5773 9.91921 13.8701C10.0087 13.9525 10.2316 14.1345 10.3507 14.1426L10.3874 14.0958C10.4175 13.9746 10.4046 13.2322 10.4043 13.0805C10.4029 12.2885 10.4974 11.8691 9.98132 11.2127C9.89697 11.0672 9.62577 10.7541 9.59172 10.602C9.46291 10.0264 9.36013 9.51041 9.05605 8.98487C8.9874 8.86621 8.99891 8.64692 9.13497 8.5858C9.3943 8.60218 10.001 9.01721 10.2667 9.17085C10.715 8.75103 10.4844 8.5985 10.6325 8.08733C10.6851 7.9056 10.8744 7.84569 11.036 7.7818Z" fill="currentColor"/><path d="M19.2891 11.2118C19.6619 11.1976 20.1613 11.1748 20.5321 11.2187C20.8361 11.2547 21.2227 11.4575 21.4141 11.72C21.6743 12.0767 21.6419 12.5929 21.6299 13.0194C21.6293 13.0398 21.5991 13.1205 21.5883 13.1271C21.3631 13.264 20.7617 13.2038 20.5199 13.2918C20.0876 13.449 19.7995 13.8743 19.427 14.1258C19.2298 14.2589 19.0503 14.355 18.8669 14.4702C17.8943 15.0815 17.1671 15.3058 16.014 15.1026C15.4509 15.0268 14.4058 14.5238 13.9186 14.1836C13.7575 14.0495 13.6081 13.8624 13.5983 13.6483C13.5498 12.5955 14.6053 12.0765 15.5156 12.011C15.8454 11.9872 16.2783 12.031 16.5827 11.9399C17.4832 11.6705 18.3426 11.2981 19.2891 11.2118Z" fill="currentColor"/><path d="M4.78791 9.24214C4.86884 9.23319 4.95031 9.22979 5.03171 9.23202C5.29514 9.24134 5.83983 9.32619 6.11147 9.37053C6.27879 9.39786 6.58964 9.52177 6.78542 9.55426C6.99434 9.58892 7.31264 9.58227 7.49743 9.63868C7.60559 9.67168 7.70267 9.73363 7.77816 9.81784C8.10987 10.1874 8.05233 11.2136 8.02001 11.7024C7.97419 11.7774 7.89729 11.8709 7.84191 11.9424C7.16058 12.0353 6.42788 11.9386 5.83067 12.1137C5.68599 12.2529 5.62517 12.4522 5.52 12.6329C5.18297 13.0255 3.57439 12.7182 3.13784 12.4315C2.62032 12.0916 2.14719 11.3827 2.48902 10.7649C2.64713 10.4793 3.22927 10.1897 3.47084 9.9747C3.95478 9.57027 4.1584 9.37105 4.78791 9.24214Z" fill="currentColor"/></svg>|
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
    |> Map.get(objective_id, ProficiencyDisplay.default_label())
  end

  defp strong_proficiency?("High"), do: true
  defp strong_proficiency?(_proficiency), do: false

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
