defmodule OliWeb.Grades.ObserveGradeUpdatesView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}

  alias OliWeb.Common.{Breadcrumb}
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  data breadcrumbs, :any
  data title, :string, default: "Observe Grade Updates"
  data section, :any, default: nil
  data updates, :any, default: []

  def set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Observe Grade Updates",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, session, socket) do
    case Mount.for(section_slug, session) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section
         )}
    end
  end

  def render(assigns) do
    ~F"""
    <div>
      Not implemented yet.
    </div>
    """
  end
end
