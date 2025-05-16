defmodule OliWeb.Sections.LtiExternalToolsView do
  use OliWeb, :live_view

  alias OliWeb.Sections.Mount
  alias OliWeb.Common.{Breadcrumb}

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, section) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "LTI 1.3 External Tools",
          link: ~p"/sections/#{section.slug}/lti_external_tools"
        })
      ]
  end

  def mount(%{"section_slug" => section_slug}, _session, socket) do
    case Mount.for(section_slug, socket) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {type, _user, section} ->
        {:ok,
         assign(socket,
           breadcrumbs: set_breadcrumbs(type, section),
           section: section
         )}
    end
  end

  def render(assigns) do
    ~H"""
    <div id="lti-external-tools" class="container flex flex-col">
      <div class="flex-1 flex flex-col">
        placeholder
      </div>
    </div>
    """
  end
end
