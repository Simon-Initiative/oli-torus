defmodule OliWeb.SectionScheduleController do
  use OliWeb, :controller

  def schedule(conn, %{"section_slug" => section_slug}) do
    section = conn.assigns.section
    # |> Oli.Repo.preload([:base_project, :root_section_resource])

    render(conn, "schedule.html",
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
