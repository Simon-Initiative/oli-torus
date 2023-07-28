defmodule OliWeb.Api.PageLifecycleController do
  use OliWeb, :controller
  alias Oli.Delivery.Attempts.PageLifecycle.FinalizationSummary
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
      {:ok,
       %FinalizationSummary{
         graded: true,
         resource_access: %Oli.Delivery.Attempts.Core.ResourceAccess{id: id},
         effective_settings: effective_settings
       }} ->
        # graded resource finalization success
        section = Sections.get_section_by(slug: section_slug)
        PageLifecycle.GradeUpdateWorker.create(section.id, id, :inline)

        is_adaptive_page? = case Oli.Publishing.DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
          %Oli.Resources.Revision{content: %{"advancedDelivery" => true}} -> true
          _ -> false
        end

        restart_url =
          Routes.page_delivery_path(
            conn,
            :page,
            section_slug,
            revision_slug
          )

        redirectTo =
          case {effective_settings.review_submission, is_adaptive_page?} do

            {:allow, false} ->
              Routes.page_delivery_path(
                conn,
                :review_attempt,
                section_slug,
                revision_slug,
                attempt_guid
              )

            _ ->
              restart_url
          end

        json(conn, %{
          result: "success",
          commandResult: "success",
          redirectTo: redirectTo,
          # Adaptive lessons will use restartUrl when the user is explicitly choosing the "restart" option
          restartUrl: restart_url
        })

      {:ok, %FinalizationSummary{graded: false}} ->
        # ungraded resource finalization success
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

      e ->
        error(e)
        command_failure(conn, "Unable to finalize page", section_slug, revision_slug)
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
    error_msg = Kernel.inspect(reason)
    Logger.error("Page finalization error encountered: #{error_msg}")
    Oli.Utils.Appsignal.capture_error(error_msg)
  end
end
