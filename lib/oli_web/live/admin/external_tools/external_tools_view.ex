defmodule OliWeb.Admin.ExternalToolsView do
  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "LTI 1.3 External Tools",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__)
        })
      ]
  end

  def mount(_, _session, socket) do
    {:ok,
     assign(socket,
       breadcrumbs: set_breadcrumbs()
     )}
  end

  def render(assigns) do
    ~H"""
    """
  end
end
