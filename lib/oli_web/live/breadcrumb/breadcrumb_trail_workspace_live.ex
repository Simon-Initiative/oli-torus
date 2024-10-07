defmodule OliWeb.Breadcrumb.BreadcrumbTrailWorkspaceLive do
  use Phoenix.LiveView
  alias OliWeb.Breadcrumb.BreadcrumbWorkspaceLive

  def mount(_params, session, socket) do
    breadcrumbs = session["breadcrumbs"]
    breadcrumbs_count = length(breadcrumbs)

    {:ok, assign(socket, breadcrumbs: breadcrumbs, breadcrumbs_count: breadcrumbs_count)}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <nav aria-label="breadcrumb overflow-hidden">
      <ol class="breadcrumb custom-breadcrumb">
        <button
          :if={@breadcrumbs_count > 1}
          disabled={if @breadcrumbs_count == 2, do: false, else: false}
          id="curriculum-back"
          class="btn btn-sm btn-link pr-5"
          phx-click="set_active"
        >
          <i class="fas fa-arrow-left"></i>
        </button>
        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <.live_component
            module={BreadcrumbWorkspaceLive}
            id={"breadcrumb-#{index}"}
            breadcrumb={breadcrumb}
            is_last={length(@breadcrumbs) - 1 == index}
            show_short={length(@breadcrumbs) > 3}
          />
        <% end %>
      </ol>
    </nav>
    """
  end

  def handle_event("set_active", _params, socket) do
    breadcrumbs = socket.assigns.breadcrumbs
    parent_link = Enum.at(breadcrumbs, length(breadcrumbs) - 2).link
    {:noreply, push_navigate(socket, to: parent_link)}
  end
end
