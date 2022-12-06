defmodule OliWeb.Api.PageLifecycleController do
  use OliWeb, :controller
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.PageLifecycle
  require Logger

  def transition(conn, %{
        "action" => "finalize",
        "section_slug" => section_slug,
        "revision_slug" => revision_slug,
        "attempt_guid" => attempt_guid
      }) do
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    case PageLifecycle.finalize(section_slug, attempt_guid, datashop_session_id) do
      {:ok, %Oli.Delivery.Attempts.Core.ResourceAccess{id: id}} ->
        section = Sections.get_section_by(slug: section_slug)
        PageLifecycle.GradeUpdateWorker.create(section.id, id, :inline)

        json(conn, %{
          result: "success",
          commandResult: "success",
          redirectTo:
            Routes.page_delivery_path(
              conn,
              :page,
              section_slug,
              revision_slug
            )
        })

      {:error, {reason}}
      when reason in [:already_submitted, :active_attempt_present, :no_more_attempts] ->
        command_failure(conn, reason, section_slug, revision_slug)

      {:error, e} ->
        error(e)
        command_failure(conn, e, section_slug, revision_slug)

      e ->
        error(e)
        command_failure(conn, e, section_slug, revision_slug)
    end
  end

  defp command_failure(conn, reason, section_slug, revision_slug) do
    json(conn, %{
      result: "success",
      commandResult: "failure",
      reason: reason,
      redirectTo: Routes.page_delivery_path(conn, :page, section_slug, revision_slug)
    })
  end

  defp error(reason) do
    Logger.error("Page finalization error encountered: #{reason}")
    Oli.Utils.Appsignal.capture_error(reason)
  end
end
