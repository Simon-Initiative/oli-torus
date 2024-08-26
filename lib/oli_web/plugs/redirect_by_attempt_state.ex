defmodule OliWeb.Plugs.RedirectByAttemptState do
  @moduledoc """
  This plug is responsible for (maybe) redirecting the user to the appropriate page route based on:
    - the type of page (practice or graded)
    - the state of the resource attempt (in the case of graded pages)

  Practice page's possible destinations:
    - lesson route
    - adaptive lesson route

  Graded page's possible destinations:
    - prologue route (if the attempt is :submitted or :evaluated)
    - lesson route (if the attempt is :active and the lesson is not adaptive)
    - adaptive lesson route (if the attempt is :active and the lesson is adaptive)


  The main objective of this plug is to prematurely redirecting the user to the appropiate page
  avoiding calls to the database (for example, building all the Oli.Delivery.Page.PageContext data and end up being redirected).

  If the user ends up being redirected, the conn will be flagged (with `already_been_redirected?` assign)
  to skip the evaluation when this plug is invoked again.
  """

  import Plug.Conn
  use OliWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    section_slug = conn.params["section_slug"]

    with false <- already_been_redirected?(conn),
         {true, current_user_id} <- user_already_authenticated?(conn),
         false <- is_attempt_review_path?(conn),
         {lesson_type, page_type, resource_id} <- get_lesson_type(conn),
         latest_resource_attempt <-
           maybe_get_resource_attempt(lesson_type, resource_id, current_user_id, section_slug) do
      case {lesson_type, page_type, latest_resource_attempt} do
        {:graded_page, _, nil} ->
          # all graded pages (adaptive or not) with no active attempt should be redirected to the prologue
          ensure_path(conn, :prologue)

        {:graded_page, _, %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: state}}
        when state in [:submitted, :evaluated] ->
          ensure_path(conn, :prologue)

        {:graded_page, :not_adaptive,
         %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}} ->
          ensure_path(conn, :lesson)

        {:graded_page, :adaptive_chromeless,
         %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}} ->
          ensure_path(conn, :adaptive_lesson)

        {:practice_page, :not_adaptive, _} ->
          # practice pages do not have prologue page.
          ensure_path(conn, :lesson)

        {:practice_page, :adaptive_chromeless, _} ->
          ensure_path(conn, :adaptive_lesson)
      end
    else
      _ ->
        conn
        |> assign(:already_been_redirected?, false)
    end
  end

  defp already_been_redirected?(conn) do
    conn.assigns[:already_been_redirected?] || false
  end

  defp user_already_authenticated?(%{assigns: %{current_user: %{id: current_user_id}}} = _conn),
    do: {true, current_user_id}

  defp user_already_authenticated?(_conn), do: {false, nil}

  defp is_attempt_review_path?(conn),
    do: !is_nil(conn.params["revision_slug"]) and !is_nil(conn.params["attempt_guid"])

  defp get_lesson_type(conn) do
    page_revision =
      Oli.Publishing.DeliveryResolver.from_revision_slug(
        conn.assigns.section.slug,
        conn.params["revision_slug"]
      )

    case {page_revision.graded, page_revision.content["advancedDelivery"],
          page_revision.content["displayApplicationChrome"]} do
      {false, true, display_application_chrome} when display_application_chrome in [nil, false] ->
        {:practice_page, :adaptive_chromeless, page_revision.resource_id}

      {false, _, _} ->
        {:practice_page, :not_adaptive, page_revision.resource_id}

      {true, true, display_application_chrome} when display_application_chrome in [nil, false] ->
        {:graded_page, :adaptive_chromeless, page_revision.resource_id}

      {true, _, _} ->
        {:graded_page, :not_adaptive, page_revision.resource_id}
    end
  end

  defp maybe_get_resource_attempt(:practice_page, _resource_id, _current_user_id, _section_slug),
    do: nil

  defp maybe_get_resource_attempt(_lesson_type, resource_id, current_user_id, section_slug) do
    Oli.Delivery.Attempts.Core.get_latest_resource_attempt(
      resource_id,
      section_slug,
      current_user_id
    )
  end

  _defp = """
  If the requested path does not match the expected path (acording to the type of page and its current state)
  the user will be redirected to the appropriate path.
  For example, if a user requested a lesson path for a graded page, but that graded page does not have an active attempt,
  then it should be redirected to the prologue path.
  """

  defp ensure_path(conn, path_type) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]

    if String.contains?(
         conn.request_path,
         "/sections/#{section_slug}/#{path_type}/#{revision_slug}"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      conn
      |> halt()
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to: "/sections/#{section_slug}/#{path_type}/#{revision_slug}?#{conn.query_string}"
      )
    end
  end
end
