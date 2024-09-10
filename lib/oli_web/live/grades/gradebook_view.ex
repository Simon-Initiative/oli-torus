defmodule OliWeb.Grades.GradebookView do
  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount

  def set_breadcrumbs(type, section) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Gradebook",
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
           section: section,
           params: %{}
         )}
    end
  end

  def handle_params(params, _, socket) do
    {:noreply,
     assign(
       socket,
       params: params
     )}
  end

  def render(assigns) do
    ~H"""
    <.live_component
      module={OliWeb.Components.Delivery.QuizScores}
      id="quiz_scores_table"
      section={@section}
      params={@params}
      patch_url_type={:gradebook_view}
    />
    """
  end
end
