defmodule OliWeb.Breadcrumb.BreadcrumbTrailWorkspaceLive do
  use Phoenix.LiveView
  alias OliWeb.Breadcrumb.BreadcrumbWorkspaceLive

  def mount(_params, session, socket) do
    breadcrumbs = session["breadcrumbs"]
    breadcrumbs_count = length(breadcrumbs)
    back_link = Enum.at(breadcrumbs, breadcrumbs_count - 2).link

    {:ok,
     assign(socket,
       breadcrumbs: breadcrumbs,
       breadcrumbs_count: breadcrumbs_count,
       back_link: back_link
     )}
  end

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <nav aria-label="breadcrumb">
      <ol class="breadcrumb custom-breadcrumb">
        <.link
          :if={@breadcrumbs_count > 1}
          id="curriculum-back"
          class="btn btn-sm btn-link pr-5"
          navigate={@back_link}
        >
          <i class="fas fa-arrow-left"></i>
        </.link>
        <%= for {breadcrumb, index} <- Enum.with_index(@breadcrumbs) do %>
          <.live_component
            module={BreadcrumbWorkspaceLive}
            id={"breadcrumb-#{index}"}
            breadcrumb={breadcrumb}
            is_last={@breadcrumbs_count - 1 == index}
            show_short={@breadcrumbs_count > 3}
          />
        <% end %>
      </ol>
    </nav>
    """
  end
end
