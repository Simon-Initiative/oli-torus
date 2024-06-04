defmodule OliWeb.Api.ActivityReportDataController do
  use OliWeb, :controller
  alias Oli.Delivery.{Sections}
  alias Oli.Activities.Reports.ProviderList

  def fetch(conn, %{
        "section_id" => section_id,
        "resource_id" => resource_id
      }) do
    user = conn.assigns.current_user

    with section <- Sections.get_section!(section_id),
         true <- Sections.is_enrolled?(user.id, section.slug) do
      revision =
        Sections.get_section_revision_for_resource(section.slug, resource_id)
        |> Oli.Repo.preload(:activity_type)

      report_provider = ProviderList.report_provider(revision.activity_type.slug)

      data =
        Oli.Activities.Reports.Renderer.report_data(
          report_provider,
          section.id,
          user.id,
          resource_id
        )

      json(conn, data)
    else
      _ -> error(conn, 403, "Forbidden")
    end
  end

  defp error(conn, code, reason) do
    conn
    |> send_resp(code, reason)
    |> halt()
  end
end
