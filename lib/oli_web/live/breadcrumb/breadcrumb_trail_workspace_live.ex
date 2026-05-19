defmodule OliWeb.Breadcrumb.BreadcrumbTrailWorkspaceLive do
  use Phoenix.LiveView
  alias OliWeb.Breadcrumb.BreadcrumbWorkspaceLive

  def mount(_params, session, socket) do
    breadcrumbs = session["breadcrumbs"]
    breadcrumbs_count = length(breadcrumbs)

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs,
       breadcrumbs_count: breadcrumbs_count
     )}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <nav aria-label="breadcrumb">
      <ol class="flex items-center">
        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <.live_component
            module={BreadcrumbWorkspaceLive}
            id={"breadcrumb-#{index}"}
            breadcrumb={breadcrumb}
            is_last={@breadcrumbs_count - 1 == index}
            is_first={index == 0}
            show_short={@breadcrumbs_count > 3}
          />
          <li :if={@breadcrumbs_count - 1 != index} class="flex items-center justify-center p-3">
            <OliWeb.Icons.chevron_right
              width="16"
              height="16"
              class="-rotate-90 text-Icon-icon-default stroke-current"
            />
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end
end
