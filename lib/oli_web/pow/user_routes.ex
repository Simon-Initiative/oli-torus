defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

  @impl true
  def after_sign_in_path(conn) do
    conn
    |> request_path_or(
      case conn.params do
        %{"user" => %{"section" => section_slug}} ->
          Routes.delivery_path(conn, :show_enroll, section_slug)

        _ ->
          Routes.delivery_path(conn, :open_and_free_index)
      end
    )
  end

  @impl true
  def after_registration_path(conn) do
    conn
    |> request_path_or(
      case conn.params do
        %{"user" => %{"section" => section_slug}} ->
          Routes.pow_session_path(conn, :new, section: section_slug)

        _ ->
          Routes.pow_session_path(conn, :new)
      end
    )
  end

  @impl true
  def after_user_updated_path(conn) do
    conn
    |> request_path_or(
      case conn.assigns[:current_user] do
        %User{independent_learner: true} ->
          Routes.delivery_path(conn, :open_and_free_index)

        _ ->
          Routes.delivery_path(conn, :index)
      end
    )
  end

  # Pow stores the request redirect path in the assigns. If that value is
  # present, we use it. Otherwise, we specify default redirect paths.
  defp request_path_or(conn, alternative) do
    if !is_nil(Map.get(conn.assigns, :request_path)) do
      conn.assigns.request_path
    else
      alternative
    end
  end

  @impl true
  def user_not_authenticated_path(conn) do
    case conn.method do
      "GET" ->
        case conn.assigns do
          # if section is open and free, redirect unauthenticated user to enroll as guest
          %{
            section: %Section{slug: section_slug, open_and_free: true, requires_enrollment: false}
          } ->
            Routes.delivery_path(conn, :show_enroll, section_slug)

          # pass section slug along for use in sign in form to redirect to enroll after sign in,
          # or embed in confirmation email link
          %{
            section: %Section{slug: section_slug}
          } ->
            Pow.Phoenix.Routes.session_path(conn, :new,
              request_path: Phoenix.Controller.current_path(conn),
              section: section_slug
            )

          # if section is a string, then it represents a section slug from a confirmation email
          # where a user will be automatically redirected to the enroll page after sign in
          %{section: section_slug} when is_binary(section_slug) ->
            Pow.Phoenix.Routes.session_path(conn, :new,
              request_path: Phoenix.Controller.current_path(conn),
              section: section_slug
            )

          _ ->
            Pow.Phoenix.Routes.session_path(conn, :new,
              request_path: Phoenix.Controller.current_path(conn)
            )
        end

      _method ->
        Pow.Phoenix.Routes.session_path(conn, :new)
    end
  end

  @impl true
  def path_for(
        %{params: %{"section" => section}} = conn,
        Pow.Phoenix.SessionController,
        :new,
        [],
        query_params
      ),
      do:
        Pow.Phoenix.Routes.path_for(
          conn,
          Pow.Phoenix.SessionController,
          :new,
          [],
          Keyword.put(query_params, :section, section)
        )

  def path_for(conn, plug, verb, vars, query_params),
    do: Pow.Phoenix.Routes.path_for(conn, plug, verb, vars, query_params)

  @impl true
  def url_for(
        conn,
        PowEmailConfirmation.Phoenix.ConfirmationController = plug,
        :show = verb,
        [_token] = vars,
        query_params
      ) do
    case conn.assigns do
      %{current_user: %{enroll_after_email_confirmation: enroll_after_email_confirmation}}
      when not is_nil(enroll_after_email_confirmation) ->
        Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params) <>
          "?section=#{enroll_after_email_confirmation}"

      _ ->
        Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params)
    end
  end

  def url_for(conn, plug, verb, vars, query_params),
    do: Pow.Phoenix.Routes.url_for(conn, plug, verb, vars, query_params)
end
