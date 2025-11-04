defmodule OliWeb.Plugs.RedirectByAttemptState do
  @moduledoc """
  This plug is responsible for (maybe) redirecting the user to the appropriate page route based on:

    - the action type (prologue, lesson or review)
    - the rendering type (adaptive or not adaptive)
    - the lesson type (practice or graded)

  Practice page's possible destinations:
    - lesson route
    - adaptive lesson route
  * practice pages do not have prologue or review.

  Not adaptive graded page's possible destinations:
    - prologue route (if the attempt is :submitted or :evaluated)
    - lesson route (if the attempt is :active)
    - review route (an attempt guid is provided in the request as a param and that attempt is finished)

  Adaptive chromeless graded page's possible destinations:
    - prologue route (if the attempt is :submitted or :evaluated)
    - adaptive lesson route (if the attempt is :active)
    - adaptive review route (an attempt guid is provided in the request as a param and that attempt is finished)

  Adaptive with chrome graded page's possible destinations:
    - prologue route (if the attempt is :submitted or :evaluated)
    - lesson route (if the attempt is :active)
    - review route (an attempt guid is provided in the request as a param and that attempt is finished)


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
         {lesson_type, page_type, resource_id, is_attempt_review_path?, page_revision} <-
           classify_request(conn),
         latest_resource_attempt <-
           maybe_get_resource_attempt(
             lesson_type,
             is_attempt_review_path?,
             resource_id,
             current_user_id,
             section_slug
           ) do
      # Check if attempt is expired for graded pages with active attempts
      attempt_expired? =
        case {lesson_type, latest_resource_attempt} do
          {:graded,
           %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active} = attempt} ->
            attempt_has_expired?(attempt, conn.assigns.section, page_revision, current_user_id)

          _ ->
            false
        end

      case {lesson_type, page_type, latest_resource_attempt, is_attempt_review_path?,
            attempt_expired?} do
        {:graded, :adaptive_chromeless, _, true, _} ->
          ensure_path(conn, :review, :adaptive)

        {:graded, :not_adaptive, _, true, _} ->
          ensure_path(conn, :review, :not_adaptive)

        {:graded, :adaptive_with_chrome, _, true, _} ->
          ensure_path(conn, :review, :not_adaptive)

        {:graded, _, nil, false, _} ->
          # all graded pages (adaptive or not) with no active attempt should be redirected to the prologue
          ensure_path(conn, :prologue)

        {:graded, _, %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: state}, false,
         _}
        when state in [:submitted, :evaluated] ->
          ensure_path(conn, :prologue)

        # If attempt has expired, redirect to prologue where it will be handled
        {:graded, _, %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}, false,
         true} ->
          ensure_path(conn, :prologue)

        {:graded, :not_adaptive,
         %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}, false, false} ->
          ensure_path(conn, :lesson)

        {:graded, :adaptive_chromeless,
         %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}, false, false} ->
          ensure_path(conn, :adaptive_lesson)

        {:graded, :adaptive_with_chrome,
         %Oli.Delivery.Attempts.Core.ResourceAttempt{lifecycle_state: :active}, false, false} ->
          ensure_path(conn, :lesson)

        {:practice, :not_adaptive, _, false, _} ->
          # practice pages do not have prologue page.
          ensure_path(conn, :lesson)

        {:practice, :not_adaptive, _, true, _} ->
          # practice pages do not have prologue page.
          ensure_path(conn, :review, :not_adaptive)

        {:practice, :adaptive_chromeless, _, false, _} ->
          ensure_path(conn, :adaptive_lesson)

        {:practice, :adaptive_chromeless, _, true, _} ->
          ensure_path(conn, :review, :adaptive)

        {:practice, :adaptive_with_chrome, _, false, _} ->
          ensure_path(conn, :lesson)

        {:practice, :adaptive_with_chrome, _, true, _} ->
          ensure_path(conn, :review, :not_adaptive)
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

  defp user_already_authenticated?(
         %{assigns: %{current_author: %{id: current_author_id}}} = _conn
       ),
       do: {true, current_author_id}

  defp user_already_authenticated?(_conn), do: {false, nil}

  defp classify_request(conn) do
    page_revision =
      Oli.Publishing.DeliveryResolver.from_revision_slug(
        conn.assigns.section.slug,
        conn.params["revision_slug"]
      )

    is_attempt_review_path? = is_attempt_review_path?(conn)

    case {page_revision.graded, page_revision.content["advancedDelivery"],
          page_revision.content["displayApplicationChrome"]} do
      # Adaptive chromeless (fullscreen)
      {false, true, display_application_chrome} when display_application_chrome in [nil, false] ->
        {:practice, :adaptive_chromeless, page_revision.resource_id, is_attempt_review_path?,
         page_revision}

      {true, true, display_application_chrome} when display_application_chrome in [nil, false] ->
        {:graded, :adaptive_chromeless, page_revision.resource_id, is_attempt_review_path?,
         page_revision}

      # Adaptive with chrome
      {false, true, true} ->
        {:practice, :adaptive_with_chrome, page_revision.resource_id, is_attempt_review_path?,
         page_revision}

      {true, true, true} ->
        {:graded, :adaptive_with_chrome, page_revision.resource_id, is_attempt_review_path?,
         page_revision}

      # Not adaptive
      {false, _, _} ->
        {:practice, :not_adaptive, page_revision.resource_id, is_attempt_review_path?,
         page_revision}

      {true, _, _} ->
        {:graded, :not_adaptive, page_revision.resource_id, is_attempt_review_path?,
         page_revision}
    end
  end

  defp is_attempt_review_path?(conn),
    do: !is_nil(conn.params["revision_slug"]) and !is_nil(conn.params["attempt_guid"])

  defp maybe_get_resource_attempt(
         :practice,
         _is_attempt_review_path?,
         _resource_id,
         _current_user_id,
         _section_slug
       ),
       do: nil

  defp maybe_get_resource_attempt(
         :graded,
         true = _is_attempt_review_path?,
         _resource_id,
         _current_user_id,
         _section_slug
       ),
       do: nil

  defp maybe_get_resource_attempt(
         _lesson_type,
         _is_attempt_review_path?,
         resource_id,
         current_user_id,
         section_slug
       ) do
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

  defp ensure_path(conn, :review, :adaptive) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]
    attempt_guid = conn.params["attempt_guid"]

    if String.contains?(
         conn.request_path,
         "/adaptive_lesson/"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      conn
      |> halt()
      |> put_session(:request_path, conn.params["request_path"])
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to:
          "/sections/#{section_slug}/adaptive_lesson/#{revision_slug}/attempt/#{attempt_guid}/review"
      )
    end
  end

  defp ensure_path(conn, :review, :not_adaptive) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]
    attempt_guid = conn.params["attempt_guid"]

    if String.contains?(
         conn.request_path,
         "/lesson/"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      conn
      |> halt()
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to: "/sections/#{section_slug}/lesson/#{revision_slug}/attempt/#{attempt_guid}/review"
      )
    end
  end

  defp ensure_path(conn, :prologue) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]

    if String.contains?(
         conn.request_path,
         "/sections/#{section_slug}/prologue"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      conn
      |> halt()
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to: "/sections/#{section_slug}/prologue/#{revision_slug}?#{conn.query_string}"
      )
    end
  end

  defp ensure_path(conn, :lesson) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]

    if String.contains?(
         conn.request_path,
         "/lesson/"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      conn
      |> halt()
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to: "/sections/#{section_slug}/lesson/#{revision_slug}?#{conn.query_string}"
      )
    end
  end

  defp ensure_path(conn, :adaptive_lesson) do
    section_slug = conn.params["section_slug"]
    revision_slug = conn.params["revision_slug"]

    if String.contains?(
         conn.request_path,
         "/adaptive_lesson/"
       ) do
      conn
      |> assign(:already_been_redirected?, false)
    else
      # adaptive lesson in iframes do not support query params in the url
      # so we store the request_path in the session.
      # * the request_path is used by the adaptive page to redirect the user back to the appropriate page
      conn
      |> halt()
      |> put_session(:request_path, conn.params["request_path"])
      |> assign(:already_been_redirected?, true)
      |> Phoenix.Controller.redirect(
        to: "/sections/#{section_slug}/adaptive_lesson/#{revision_slug}"
      )
    end
  end

  defp attempt_has_expired?(resource_attempt, section, page_revision, user_id) do
    # Get the effective settings for this resource (reusing already-loaded data)
    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(
        page_revision,
        section.id,
        user_id
      )

    # Check if late submissions are disallowed (meaning we enforce the deadline)
    late_submit_disallowed = effective_settings.late_submit == :disallow

    if late_submit_disallowed do
      # Determine the effective deadline
      effective_end_time =
        Oli.Delivery.Settings.determine_effective_deadline(
          resource_attempt,
          effective_settings
        )

      # Check if current time is past the deadline
      case effective_end_time do
        nil ->
          false

        deadline ->
          DateTime.compare(DateTime.utc_now(), deadline) == :gt
      end
    else
      false
    end
  end
end
