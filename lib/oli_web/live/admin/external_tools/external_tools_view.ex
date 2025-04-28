defmodule OliWeb.Admin.ExternalToolsView do
  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.Utils

  defp set_breadcrumbs() do
    OliWeb.Admin.AdminView.breadcrumb()
    |> breadcrumb()
  end

  def breadcrumb(previous) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Manage LTI 1.3 External Tools",
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

  def handle_params(params, _, socket) do
    {:noreply, assign(socket, search_term: params["search_term"])}
  end

  def render(assigns) do
    ~H"""
    <Utils.search_box placeholder="Search tools..." search_term={@search_term} class="w-1/3" />
    """
  end

  def handle_event("clear_search", _, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools"
     )}
  end

  def handle_event("search", %{"search_term" => ""}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools"
     )}
  end

  def handle_event("search", %{"search_term" => search_term}, socket) do
    {:noreply,
     push_patch(socket,
       to: ~p"/admin/external_tools?search_term=#{search_term}"
     )}
  end
end
