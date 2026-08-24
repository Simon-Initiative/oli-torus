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

  def render(assigns) do
    ~H"""
    <div id="accordion" class="flex flex-col gap-2 font-open-sans">
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
              aria-expanded={expanded?}
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
                <span class="min-w-0">{item.title}</span>
              </span>
            </button>

            <div class="flex shrink-0 items-center gap-2 self-end sm:self-auto">
              <button
                type="button"
                class="inline-flex size-[22px] items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-hover active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
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
                class="inline-flex size-[22px] items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-danger active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
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

          <div class="flex flex-wrap gap-3 px-3 pb-4">
            <.metadata_pill label={pluralized_count(item.page_attachments_count, "Page", "Pages")}>
              <Icons.book
                width="13"
                height="14"
                stroke_width="1.41573"
                variant="objective"
                class="shrink-0 text-current"
              />
            </.metadata_pill>
            <.metadata_pill label={
              pluralized_count(item.sub_objectives_count, "Sub-Objective", "Sub-Objectives")
            } />
            <.metadata_pill label={
              pluralized_count(item.activity_attachments_count, "Activity", "Activities")
            }>
              <Icons.clipboard
                width="13"
                height="16"
                stroke_width="1.45455"
                variant="objective"
                class="shrink-0 text-current"
              />
            </.metadata_pill>
          </div>

          <div
            :if={expanded?}
            id={"collapse#{index}"}
            class="collapse show border-t border-Border-border-default"
            aria-labelledby={"heading#{index}"}
          >
            <div class="flex flex-col gap-4 px-4 pb-5 pt-[17px]">
              <section class="flex flex-col gap-3">
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
                        "group/item flex items-center gap-[10px] rounded-md border border-Border-border-default bg-Background-bg-secondary p-3",
                        MapSet.member?(@pending_delete_slugs, sub_objective.slug) && "opacity-50"
                      ]}
                    >
                      <span class="flex h-[15px] w-2.5 shrink-0 items-center justify-center text-Text-text-low-alpha">
                        <Icons.chevron_down
                          width="9.5"
                          height="5.5"
                          variant="stroke"
                          class="shrink-0 -rotate-90 text-current"
                        />
                      </span>
                      <div class={[
                        "min-w-0 flex-1 text-sm font-normal leading-[19.25px] text-Text-text-high",
                        MapSet.member?(@pending_delete_slugs, sub_objective.slug) && "line-through"
                      ]}>
                        {sub_objective.title}
                      </div>
                      <.loader
                        :if={MapSet.member?(@pending_delete_slugs, sub_objective.slug)}
                        class="ml-2"
                        icon_class="text-secondary"
                      />
                      <div
                        :if={!MapSet.member?(@pending_delete_slugs, sub_objective.slug)}
                        class="flex h-[23px] w-[60px] shrink-0 items-center gap-2 pl-2"
                      >
                        <button
                          type="button"
                          class="inline-flex size-[22px] items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-hover active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
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
                          class="inline-flex size-[22px] items-center justify-center rounded p-1 text-Icon-icon-default transition-colors hover:text-Icon-icon-danger active:text-Icon-icon-active focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
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
  slot :inner_block

  defp metadata_pill(assigns) do
    ~H"""
    <span class="inline-flex h-8 items-center gap-1.5 rounded-full border border-Border-border-default bg-Background-bg-secondary px-[13px] py-0 text-[13px] font-semibold leading-5 text-Text-text-high">
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

  defp pluralized_count(1, singular, _plural), do: "1 #{singular}"
  defp pluralized_count(count, _singular, plural), do: "#{count} #{plural}"
end
