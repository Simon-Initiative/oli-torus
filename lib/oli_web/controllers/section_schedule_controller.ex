defmodule OliWeb.SectionScheduleController do
  use OliWeb, :controller
  alias OliWeb.Common.{Breadcrumb}

  def breadcrumb(section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(:instructor, section) ++
      [
        Breadcrumb.new(%{
          full_title: "Section Schedule",
          link: Routes.section_schedule_path(OliWeb.Endpoint, :schedule, section.slug)
        })
      ]
  end

  def schedule(conn, %{"section_slug" => section_slug}) do
    section = conn.assigns.section
    # |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "schedule.html",
      breadcrumbs: breadcrumb(section),
      title: section.title,
      context: %{
        start_date: section.start_date,
        end_date: section.end_date,
        title: section.title,
        section_slug: section_slug,
        display_curriculum_item_numbering: section.display_curriculum_item_numbering
      }
    )
  end
end
