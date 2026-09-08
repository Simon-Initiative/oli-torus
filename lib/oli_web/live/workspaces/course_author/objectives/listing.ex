defmodule OliWeb.Workspaces.CourseAuthor.Objectives.Listing do
  use OliWeb, :html

  import OliWeb.Components.Common

  alias OliWeb.Icons
  alias OliWeb.Workspaces.CourseAuthor.Objectives.Actions

  attr(:project_slug, :string, required: true)
  attr(:revision_history_link, :boolean, required: true)
  attr(:rows, :list, required: true)
  attr(:expanded_slugs, :any, default: MapSet.new())
  attr(:pending_delete_slugs, :any, default: MapSet.new())
  attr(:offset, :integer, default: 0)
  attr(:query, :string, default: "")

  def render(assigns) do
    assigns =
      assign(assigns, :highlight_terms, highlight_terms(assigns.query))

    assigns = assign(assigns, :highlight_regex, highlight_regex(assigns.highlight_terms))

    ~H"""
    <div id="accordion" class="flex flex-col gap-3 font-open-sans">
      <%= for {item, index} <- Enum.with_index(@rows, 1) do %>
        <% expanded? = MapSet.member?(@expanded_slugs, item.slug) %>

        <article
          id={item.slug}
          class="group max-w-full overflow-hidden rounded-lg border border-Border-border-default bg-Background-bg-secondary shadow-[0px_2px_2.5px_rgba(0,50,99,0.05)]"
        >
          <div
            class="flex flex-col items-center gap-3 px-3 py-4 sm:flex-row sm:justify-between"
            id={"heading#{index}"}
          >
            <button
              class="flex min-w-0 flex-1 items-center gap-3 rounded-md text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
              aria-expanded={to_string(expanded?)}
              aria-controls={"collapse#{index}"}
              phx-click="toggle_objective"
              phx-value-slug={item.slug}
            >
              <span class="flex h-1.5 w-2.5 shrink-0 items-center justify-center text-Text-text-low-alpha">
                <Icons.chevron_down
                  width="9.5"
                  height="5.5"
                  variant="stroke"
                  class={[
                    "shrink-0 text-current transition-transform",
                    !expanded? && "-rotate-90"
                  ]}
                />
              </span>
              <span class="flex min-h-[22.5px] shrink-0 translate-y-px items-center whitespace-nowrap text-[13px] font-bold uppercase leading-[19.5px] text-Text-text-low-alpha">
                <span>{"LO #{@offset + index}"}</span>
              </span>
              <span class="flex min-h-[22.5px] min-w-0 flex-1 items-center text-[15px] font-semibold leading-[22.5px] text-Text-text-high">
                <span class="min-w-0">
                  <.highlighted_title
                    title={item.title}
                    regex={@highlight_regex}
                    terms={@highlight_terms}
                  />
                </span>
              </span>
            </button>

            <div class="flex shrink-0 items-center gap-2 self-end sm:self-auto">
              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-hover active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                phx-click="display_edit_modal"
                phx-value-slug={item.slug}
                aria-label={"Edit #{item.title}"}
                title={"Edit #{item.title}"}
              >
                <Icons.edit
                  width="14"
                  height="14"
                  stroke_width="1.26"
                  variant="objective"
                  class="shrink-0 text-current"
                />
              </button>

              <button
                type="button"
                class="inline-flex size-9 items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-danger active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                phx-click="display_delete_modal"
                phx-value-slug={item.slug}
                aria-label={"Delete #{item.title}"}
                title={"Delete #{item.title}"}
              >
                <Icons.trash
                  width="14"
                  height="15"
                  stroke_width="1.23853"
                  variant="objective"
                  class="shrink-0 text-current"
                />
              </button>

              <.link
                :if={@revision_history_link}
                navigate={
                  ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{item.slug}/history"
                }
                class="rounded-md px-1 text-xs font-semibold text-Text-text-button hover:text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
              >
                View revision history
              </.link>
            </div>
          </div>

          <div
            :if={!expanded?}
            id={"objective-summary-#{item.resource_id}"}
            class="flex flex-wrap gap-3 px-3 pb-4"
          >
            <.metadata_pill label={pluralized_count(item.page_attachments_count, "Page", "Pages")}>
              <Icons.book
                width="13"
                height="14"
                stroke_width="1.41573"
                variant="objective"
                class="shrink-0 text-current"
              />
            </.metadata_pill>
            <span class="inline-flex min-h-[30px] items-center rounded-[12px] border border-Border-border-default px-[13px] py-1 text-[13px] font-semibold leading-[19.5px] text-Text-text-high">
              {pluralized_count(item.sub_objectives_count, "Sub-Objective", "Sub-Objectives")}
            </span>
            <.metadata_pill label={
              pluralized_count(
                item.formative_activity_attachments_count,
                "Formative",
                "Formative"
              )
            }>
              <Icons.practice is_active={false} />
            </.metadata_pill>
            <.metadata_pill label={
              pluralized_count(
                item.summative_activity_attachments_count,
                "Summative",
                "Summative"
              )
            }>
              <Icons.assignments is_active={false} />
            </.metadata_pill>
          </div>

          <div
            :if={expanded?}
            id={"collapse#{index}"}
            class="collapse show border-t border-Border-border-default"
            aria-labelledby={"heading#{index}"}
          >
            <div class="flex flex-col gap-5 px-4 pb-5 pt-[17px]">
              <section :if={item.has_coverage} class="order-1 flex flex-col gap-3">
                <div class="flex items-center justify-start gap-4">
                  <div
                    class="inline-flex items-center rounded-md border border-Border-border-default bg-Surface-surface-secondary-muted p-1"
                    role="group"
                    aria-label="Assessment bucket"
                  >
                    <button
                      type="button"
                      class={bucket_button_class(item.assessment_bucket == :formative)}
                      aria-pressed={to_string(item.assessment_bucket == :formative)}
                      phx-click="set_assessment_bucket"
                      phx-value-objective_id={item.resource_id}
                      phx-value-bucket="formative"
                    >
                      <Icons.practice is_active={item.assessment_bucket == :formative} />
                      {item.formative_activity_attachments_count} Formative
                    </button>
                    <button
                      type="button"
                      class={bucket_button_class(item.assessment_bucket == :summative)}
                      aria-pressed={to_string(item.assessment_bucket == :summative)}
                      phx-click="set_assessment_bucket"
                      phx-value-objective_id={item.resource_id}
                      phx-value-bucket="summative"
                    >
                      <Icons.assignments is_active={item.assessment_bucket == :summative} />
                      {item.summative_activity_attachments_count} Summative
                    </button>
                  </div>
                </div>
                <.coverage_details
                  item={item}
                  project_slug={@project_slug}
                  regex={@highlight_regex}
                  terms={@highlight_terms}
                />
              </section>

              <section class="order-2 flex flex-col gap-3">
                <div class="flex items-center justify-between gap-4">
                  <div class="text-[17px] font-bold leading-[25.5px] text-Text-text-high">
                    Sub-Objectives
                  </div>
                  <Actions.actions slug={item.slug} />
                </div>
                <ul class="m-0 flex list-none flex-col gap-2 p-0">
                  <%= for sub_objective <- item.children do %>
                    <li
                      :if={!is_nil(sub_objective)}
                      class={[
                        "group/item flex flex-wrap items-center gap-[10px] rounded-md border border-Border-border-default bg-Background-bg-secondary p-3",
                        MapSet.member?(@pending_delete_slugs, sub_objective.slug) && "opacity-50"
                      ]}
                    >
                      <% child_expanded? = MapSet.member?(@expanded_slugs, sub_objective.slug) %>
                      <button
                        type="button"
                        class="flex min-w-0 flex-1 items-center gap-3 rounded-md text-left focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary disabled:cursor-default"
                        disabled={!sub_objective.has_coverage}
                        aria-expanded={to_string(child_expanded?)}
                        aria-controls={
                          if sub_objective.has_coverage,
                            do: "sub-objective-coverage-#{sub_objective.resource_id}"
                        }
                        phx-click="toggle_objective"
                        phx-value-slug={sub_objective.slug}
                      >
                        <span
                          id={"sub-objective-chevron-#{item.slug}-#{sub_objective.resource_id}"}
                          class="flex h-[15px] w-2.5 shrink-0 items-center justify-center text-Text-text-low-alpha"
                        >
                          <Icons.chevron_down
                            :if={sub_objective.has_coverage}
                            width="9.5"
                            height="5.5"
                            variant="stroke"
                            class={[
                              "shrink-0 text-current transition-transform",
                              !child_expanded? && "-rotate-90"
                            ]}
                          />
                        </span>
                        <span class={[
                          "min-w-0 flex-1 text-sm font-normal leading-[19.25px] text-Text-text-high",
                          MapSet.member?(@pending_delete_slugs, sub_objective.slug) && "line-through"
                        ]}>
                          <.highlighted_title
                            title={sub_objective.title}
                            regex={@highlight_regex}
                            terms={@highlight_terms}
                          />
                        </span>
                      </button>
                      <.loader
                        :if={MapSet.member?(@pending_delete_slugs, sub_objective.slug)}
                        class="ml-2"
                        icon_class="text-secondary"
                      />
                      <div
                        :if={!MapSet.member?(@pending_delete_slugs, sub_objective.slug)}
                        class="flex shrink-0 items-center gap-4"
                      >
                        <div
                          id={"sub-objective-summary-#{item.slug}-#{sub_objective.resource_id}"}
                          class="flex shrink-0 items-center gap-1"
                          aria-label={"Activity coverage summary for #{sub_objective.title}"}
                        >
                          <span
                            class="inline-flex min-h-[26px] items-center gap-1 rounded-full border border-Border-border-default bg-Background-bg-secondary px-1.5 py-0.5 text-xs font-semibold leading-[18px] text-Text-text-high"
                            aria-label={"#{sub_objective.formative_activity_attachments_count} formative activities"}
                          >
                            <Icons.practice is_active={false} />
                            <span>{sub_objective.formative_activity_attachments_count}</span>
                          </span>
                          <span
                            class="inline-flex min-h-[26px] items-center gap-1 rounded-full border border-Border-border-default bg-Background-bg-secondary px-1.5 py-0.5 text-xs font-semibold leading-[18px] text-Text-text-high"
                            aria-label={"#{sub_objective.summative_activity_attachments_count} summative activities"}
                          >
                            <Icons.assignments is_active={false} />
                            <span>{sub_objective.summative_activity_attachments_count}</span>
                          </span>
                        </div>

                        <div class="flex shrink-0 items-center gap-2">
                          <button
                            type="button"
                            class="inline-flex size-9 items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-hover active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                            phx-click="display_edit_modal"
                            phx-value-slug={sub_objective.slug}
                            aria-label={"Edit #{sub_objective.title}"}
                            title={"Edit #{sub_objective.title}"}
                          >
                            <Icons.edit
                              width="14"
                              height="14"
                              stroke_width="1.26"
                              variant="objective"
                              class="shrink-0 text-current"
                            />
                          </button>
                          <button
                            type="button"
                            class="inline-flex size-9 items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-danger active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                            phx-click="display_sub_objective_delete_modal"
                            phx-value-slug={sub_objective.slug}
                            phx-value-parent_slug={item.slug}
                            phx-value-title={sub_objective.title}
                            aria-label={"Delete #{sub_objective.title}"}
                            title={"Delete #{sub_objective.title}"}
                          >
                            <Icons.trash
                              width="14"
                              height="15"
                              stroke_width="1.23853"
                              variant="objective"
                              class="shrink-0 text-current"
                            />
                          </button>
                        </div>
                      </div>
                      <div
                        :if={child_expanded? and sub_objective.has_coverage}
                        id={"sub-objective-coverage-#{sub_objective.resource_id}"}
                        class="basis-full border-t border-Border-border-default pt-3"
                      >
                        <div class="mb-3 flex items-center justify-start gap-4">
                          <div
                            class="inline-flex items-center rounded-md border border-Border-border-default bg-Surface-surface-secondary-muted p-1"
                            role="group"
                            aria-label="Assessment bucket"
                          >
                            <button
                              type="button"
                              class={
                                bucket_button_class(sub_objective.assessment_bucket == :formative)
                              }
                              aria-pressed={to_string(sub_objective.assessment_bucket == :formative)}
                              phx-click="set_assessment_bucket"
                              phx-value-objective_id={sub_objective.resource_id}
                              phx-value-bucket="formative"
                            >
                              <Icons.practice is_active={
                                sub_objective.assessment_bucket == :formative
                              } />
                              {sub_objective.formative_activity_attachments_count} Formative
                            </button>
                            <button
                              type="button"
                              class={
                                bucket_button_class(sub_objective.assessment_bucket == :summative)
                              }
                              aria-pressed={to_string(sub_objective.assessment_bucket == :summative)}
                              phx-click="set_assessment_bucket"
                              phx-value-objective_id={sub_objective.resource_id}
                              phx-value-bucket="summative"
                            >
                              <Icons.assignments is_active={
                                sub_objective.assessment_bucket == :summative
                              } />
                              {sub_objective.summative_activity_attachments_count} Summative
                            </button>
                          </div>
                        </div>
                        <.coverage_details
                          item={sub_objective}
                          project_slug={@project_slug}
                          regex={@highlight_regex}
                          terms={@highlight_terms}
                        />
                      </div>
                    </li>
                  <% end %>
                </ul>
              </section>
            </div>
          </div>
        </article>
      <% end %>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block

  defp metadata_pill(assigns) do
    ~H"""
    <span class={[
      "inline-flex min-h-[30px] items-center gap-1.5 rounded-[12px] px-[13px] py-1 text-[13px] font-semibold leading-[19.5px]",
      @class ||
        "border border-Border-border-default bg-Background-bg-secondary text-Text-text-high"
    ]}>
      <span
        :if={@inner_block != []}
        class="inline-flex h-5 w-[13px] shrink-0 items-center justify-center text-Text-text-high"
      >
        {render_slot(@inner_block)}
      </span>
      <span class="inline-flex h-5 items-center">{@label}</span>
    </span>
    """
  end

  attr :item, :map, required: true
  attr :project_slug, :string, required: true
  attr :regex, :any, required: true
  attr :terms, :list, required: true

  defp coverage_details(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <%= if @item.coverage_details == [] do %>
        <p class="m-0 rounded-md bg-Background-bg-secondary px-3 py-2 text-sm text-Text-text-low-alpha">
          No pages or activities are attached for this assessment bucket.
        </p>
      <% else %>
        <ul class="m-0 flex list-none flex-col gap-4 p-0">
          <%= for page <- @item.coverage_details do %>
            <li class="flex flex-col gap-2">
              <div class="border-b border-Border-border-subtle pb-2">
                <.link
                  href={
                    ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{page.page.slug}/edit"
                  }
                  class="flex items-center gap-1.5 rounded text-sm font-semibold leading-[21px] text-Text-text-button hover:text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                  aria-label={"Open page editor for #{page.page.title || page.page.slug}"}
                >
                  <Icons.book width="12" height="13" stroke_width="1.41573" variant="objective" />
                  <span>
                    <.highlighted_title
                      title={page.page.title || page.page.slug}
                      regex={@regex}
                      terms={@terms}
                    />
                  </span>
                </.link>
              </div>
              <%= if page.activities == [] do %>
                <p class="m-0 pl-0.5 text-xs leading-[18px] text-Text-text-low-alpha">
                  No activities are attached for this assessment bucket.
                </p>
              <% else %>
                <ul class="m-0 flex list-none flex-col gap-1 p-0">
                  <%= for activity <- page.activities do %>
                    <li class="flex h-[42px] items-center rounded-md border border-Border-border-default px-[13px] py-[7px]">
                      <.link
                        href={
                          ~p"/workspaces/course_author/#{@project_slug}/curriculum/#{page.page.slug}/edit#activity_#{activity.resource_id}"
                        }
                        class="flex min-w-0 items-center gap-2 rounded text-[13px] font-semibold leading-[19.5px] text-Text-text-button hover:text-Text-text-button focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                        aria-label={"Open activity #{activity.title || activity.slug} in #{page.page.title || page.page.slug}"
                        }
                      >
                        <span class="flex size-7 shrink-0 items-center justify-center rounded-full bg-Fill-Accent-fill-accent-blue p-1">
                          <%= if page.page.graded do %>
                            <Icons.assignments is_active={false} />
                          <% else %>
                            <Icons.practice is_active={false} />
                          <% end %>
                        </span>
                        <span class="min-w-0 truncate">
                          <.highlighted_title
                            title={activity.title || activity.slug}
                            regex={@regex}
                            terms={@terms}
                          />
                        </span>
                      </.link>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </li>
          <% end %>
        </ul>
      <% end %>
    </div>
    """
  end

  defp bucket_button_class(true),
    do:
      "inline-flex h-[27px] items-center gap-1.5 rounded bg-Fill-Accent-fill-accent-blue px-3 py-1 text-sm font-semibold leading-4 text-Text-text-high whitespace-nowrap shadow-[0px_1px_1.5px_rgba(0,0,0,0.1),0px_1px_1px_rgba(0,0,0,0.1)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"

  defp bucket_button_class(false),
    do:
      "inline-flex h-[27px] items-center gap-1.5 rounded px-3 py-1 text-sm font-semibold leading-4 text-Text-text-low whitespace-nowrap focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"

  defp pluralized_count(1, singular, _plural), do: "1 #{singular}"
  defp pluralized_count(count, _singular, plural), do: "#{count} #{plural}"

  attr :title, :string, required: true
  attr :regex, :any, required: true
  attr :terms, :list, required: true

  defp highlighted_title(assigns) do
    ~H"""
    <%= for {part, highlighted?} <- highlight_parts(@title, @regex, @terms) do %>
      <%= if highlighted? do %>
        <mark>{part}</mark>
      <% else %>
        <span>{part}</span>
      <% end %>
    <% end %>
    """
  end

  defp highlight_terms(query) do
    query
    |> String.slice(0, 100)
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(10)
  end

  defp highlight_regex(terms) do
    case terms do
      [] -> nil
      terms -> Regex.compile!("(#{Enum.map_join(terms, "|", &Regex.escape/1)})", "iu")
    end
  end

  defp highlight_parts(title, nil, _terms), do: [{title, false}]

  defp highlight_parts(title, regex, terms) do
    Regex.split(regex, title, include_captures: true)
    |> Enum.map(fn part ->
      {part, Enum.any?(terms, &(String.downcase(&1) == String.downcase(part)))}
    end)
  end
end
