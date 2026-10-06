defmodule OliWeb.Workspaces.CourseAuthor.Objectives.SelectExistingSubModal do
  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.Button

  def update(assigns, socket) do
    query = Map.get(socket.assigns, :query, "")

    {:ok,
     socket
     |> assign(
       add: assigns.add,
       id: assigns.id,
       parent_slug: assigns.parent_slug,
       query: query,
       sub_objectives: assigns.sub_objectives
     )
     |> assign_filtered_sub_objectives()}
  end

  attr(:add, :string, required: true)
  attr(:filtered_sub_objectives, :list, default: [])
  attr(:id, :string)
  attr(:parent_slug, :string, required: true)
  attr(:query, :string, default: "")
  attr(:sub_objectives, :list, default: [])

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      style="display: block"
      tabindex="-1"
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-dialog-centered !max-w-[860px]" role="document">
        <div class="modal-content !rounded-2xl border-0 bg-Background-bg-secondary shadow-xl">
          <div class="flex items-center px-8 pb-6 pt-8 sm:px-16 sm:pt-16">
            <h2
              id={"#{@id}-title"}
              class="m-0 text-2xl font-bold leading-9 text-Text-text-high"
            >
              Select Existing Sub-Objective
            </h2>
            <Button.button
              variant={:close}
              class="absolute right-3 top-3 inline-flex !size-11 items-center justify-center text-Icon-icon-default focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
              data-bs-dismiss="modal"
              aria-label="Close Select Existing Sub-Objective dialog"
            />
          </div>

          <div class="px-8 pb-10 sm:pb-16 sm:pl-16 sm:pr-9">
            <form
              id={"#{@id}-filters"}
              class="mb-6 flex flex-col gap-3 sm:flex-row sm:gap-6"
              phx-change="filters_changed"
              phx-submit="filters_changed"
              phx-target={@myself}
            >
              <label class="relative min-w-0 sm:w-56 sm:flex-none" for={"#{@id}-search"}>
                <span class="sr-only">Search sub-objectives</span>
                <i
                  class="fa-solid fa-magnifying-glass pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-Icon-icon-default"
                  aria-hidden="true"
                >
                </i>
                <input
                  id={"#{@id}-search"}
                  name="query"
                  type="search"
                  value={@query}
                  placeholder="Search..."
                  phx-debounce="250"
                  class="h-9 w-full rounded-md border border-Border-border-default bg-Background-bg-secondary pl-10 pr-3 text-sm text-Text-text-high placeholder:text-Text-text-low-alpha focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                />
              </label>
            </form>

            <p
              :if={@filtered_sub_objectives == []}
              id={"#{@id}-empty"}
              class="m-0 rounded-md border border-Border-border-default px-4 py-6 text-center text-sm text-Text-text-low-alpha"
            >
              No sub-objectives match these filters.
            </p>

            <ul class="m-0 flex list-none flex-col gap-2 p-0">
              <li
                :for={sub_objective <- @filtered_sub_objectives}
                id={"existing-sub-objective-#{sub_objective.resource_id}"}
                class="flex flex-col gap-3 rounded-md py-2 sm:flex-row sm:items-center"
              >
                <span class="min-w-0 flex-1 text-base leading-6 text-Text-text-high">
                  {sub_objective.title}
                </span>
                <div class="flex shrink-0 gap-2">
                  <button
                    type="button"
                    class="inline-flex h-11 items-center justify-center rounded-md border border-Fill-Buttons-fill-primary px-6 text-sm font-semibold leading-4 text-Text-text-button hover:bg-Fill-Buttons-fill-primary hover:text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    phx-value-slug={sub_objective.slug}
                    phx-value-parent_slug={@parent_slug}
                    phx-click={@add}
                    aria-label={"Add #{sub_objective.title} to this learning objective"}
                  >
                    Add
                  </button>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("filters_changed", params, socket) do
    {:noreply,
     socket
     |> assign(query: Map.get(params, "query", socket.assigns.query))
     |> assign_filtered_sub_objectives()}
  end

  defp assign_filtered_sub_objectives(socket) do
    query = String.downcase(String.trim(socket.assigns.query))

    filtered_sub_objectives =
      socket.assigns.sub_objectives
      |> Enum.filter(fn sub_objective ->
        query == "" or String.contains?(String.downcase(sub_objective.title), query)
      end)

    assign(socket, filtered_sub_objectives: filtered_sub_objectives)
  end
end
