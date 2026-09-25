defmodule OliWeb.Workspaces.CourseAuthor.Objectives.SelectExistingSubModal do
  use OliWeb, :live_component

  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Icons

  def update(assigns, socket) do
    query = Map.get(socket.assigns, :query, "")
    status = Map.get(socket.assigns, :status, "all")

    {:ok,
     socket
     |> assign(
       add: assigns.add,
       delete: assigns.delete,
       focus_delete_slug: assigns.focus_delete_slug,
       id: assigns.id,
       parent_slug: assigns.parent_slug,
       query: query,
       status: status,
       sub_objectives: assigns.sub_objectives
     )
     |> assign_filtered_sub_objectives()}
  end

  attr(:add, :string, required: true)
  attr(:delete, :string, required: true)
  attr(:filtered_sub_objectives, :list, default: [])
  attr(:focus_delete_slug, :string, default: nil)
  attr(:id, :string)
  attr(:parent_slug, :string, required: true)
  attr(:query, :string, default: "")
  attr(:status, :string, default: "all")
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
      data-initial-focus={@focus_delete_slug && "#delete-sub-objective-#{@focus_delete_slug}"}
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

              <label
                class={[
                  "relative",
                  if(@status == "unassociated", do: "sm:w-[150px]", else: "sm:w-[95px]")
                ]}
                for={"#{@id}-status"}
              >
                <span class="sr-only">Filter sub-objectives by association status</span>
                <select
                  id={"#{@id}-status"}
                  name="status"
                  class="h-9 w-full appearance-none rounded-md border border-Border-border-default bg-Background-bg-secondary px-3 pr-9 text-sm text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                >
                  <option value="all" selected={@status == "all"}>Status</option>
                  <option value="associated" selected={@status == "associated"}>Associated</option>
                  <option value="unassociated" selected={@status == "unassociated"}>
                    Unassociated
                  </option>
                </select>
                <Icons.chevron_down
                  width="9.5"
                  height="5.5"
                  variant="stroke"
                  class="pointer-events-none absolute right-3 top-1/2 -translate-y-1/2 text-Icon-icon-default"
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
                    class="inline-flex h-8 items-center justify-center rounded-md border border-Fill-Buttons-fill-primary px-6 text-sm font-semibold leading-4 text-Text-text-button hover:bg-Fill-Buttons-fill-primary hover:text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
                    phx-value-slug={sub_objective.slug}
                    phx-value-parent_slug={@parent_slug}
                    phx-click={@add}
                    aria-label={"Add #{sub_objective.title} to this learning objective"}
                  >
                    Add
                  </button>
                  <button
                    :if={sub_objective.association_count == 0}
                    id={"delete-sub-objective-#{sub_objective.slug}"}
                    type="button"
                    class="inline-flex h-8 items-center justify-center rounded-md border border-Border-border-danger px-6 text-sm font-semibold leading-4 text-Text-text-danger hover:bg-Fill-fill-danger hover:text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Icon-icon-danger"
                    phx-value-slug={sub_objective.slug}
                    phx-value-parent_slug={@parent_slug}
                    phx-click={@delete}
                    aria-label={"Permanently delete #{sub_objective.title}"}
                  >
                    Delete
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
     |> assign(
       query: Map.get(params, "query", socket.assigns.query),
       status: Map.get(params, "status", socket.assigns.status)
     )
     |> assign_filtered_sub_objectives()}
  end

  defp assign_filtered_sub_objectives(socket) do
    query = String.downcase(String.trim(socket.assigns.query))

    filtered_sub_objectives =
      socket.assigns.sub_objectives
      |> Enum.filter(fn sub_objective ->
        query == "" or String.contains?(String.downcase(sub_objective.title), query)
      end)
      |> Enum.filter(&matches_status?(&1, socket.assigns.status))

    assign(socket, filtered_sub_objectives: filtered_sub_objectives)
  end

  defp matches_status?(sub_objective, "associated"), do: sub_objective.association_count > 0
  defp matches_status?(sub_objective, "unassociated"), do: sub_objective.association_count == 0
  defp matches_status?(_sub_objective, _status), do: true
end
