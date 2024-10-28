defmodule OliWeb.Pow.UserRoutes do
  use Pow.Phoenix.Routes
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  @impl true
  def after_sign_in_path(conn, after_sign_in_target \\ :instructor_workspace) do
    conn
    |> request_path_or(
      case {conn.params, Plug.Conn.get_session(conn, :enrollment_path)} do
        {%{"user" => %{"section" => section_slug}}, _enrollment_path} ->
          Routes.delivery_path(conn, :show_enroll, section_slug)

        {_params, enrollment_path} when is_binary(enrollment_path) ->
          Plug.Conn.delete_session(conn, :enrollment_path)
          enrollment_path

        {%{"provider" => provider}, _enrollment_path} when provider in ["google", "github"] ->
          case conn.assigns.current_user do
            %Oli.Accounts.User{} -> workspace_path(conn, :student_workspace)
            _ -> workspace_path(conn, after_sign_in_target)
          end

        _ ->
          workspace_path(conn, after_sign_in_target)
      end
    )
  end

  defp workspace_path(conn, :instructor_workspace),
    do: Routes.live_path(conn, OliWeb.Workspaces.Instructor.IndexLive)

  defp workspace_path(conn, :student_workspace),
    do: Routes.live_path(conn, OliWeb.Workspaces.Student)

  defp workspace_path(conn, :course_author_workspace),
    do: Routes.live_path(conn, OliWeb.Workspaces.CourseAuthor)

  @impl true
  def after_registration_path(conn) do
    conn
    |> request_path_or(
      case conn.params do
        %{"user" => %{"section" => section_slug}} ->
          case Sections.get_section_by_slug(section_slug) do
            %Section{skip_email_verification: true} ->
              Routes.delivery_path(conn, :show_enroll, section_slug)

            _ ->
              Routes.pow_session_path(conn, :new, section: section_slug)
          end

        _ ->
          Routes.pow_session_path(conn, :new)
      end
    )
  end

  @impl true
  def after_user_updated_path(conn) do
    conn
    |> request_path_or(Routes.pow_registration_path(OliWeb.Endpoint, :edit))
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
            Routes.delivery_path(
              conn,
              :show_enroll,
              section_slug,
              params_for(conn, [:from_invitation_link?])
            )

          # if section is a string, then it represents a section slug from a confirmation email
          # where a user will be automatically redirected to the enroll page after sign in
          %{section: _section, user_type: :student} ->
            ~p"/?#{params_for(conn, [:request_path, :section, :from_invitation_link?])}"

          %{section: _section} ->
            Pow.Phoenix.Routes.session_path(
              conn,
              :new,
              params_for(conn, [:request_path, :section, :from_invitation_link?])
            )

          _ ->
            Pow.Phoenix.Routes.session_path(
              conn,
              :new,
              params_for(conn, [:request_path, :from_invitation_link?])
            )
        end

      _method ->
        Pow.Phoenix.Routes.session_path(conn, :new, params_for(conn, [:from_invitation_link?]))
    end
  end

  defp params_for(conn, params),
    do: Enum.reduce(params, %{}, &add_param(&1, &2, conn))

  defp add_param(:from_invitation_link?, params, conn) do
    from_invitation_link? =
      conn
      |> Phoenix.Controller.current_path()
      |> String.contains?(~p"/sections/join")

    if from_invitation_link?, do: Map.put(params, :from_invitation_link?, true), else: params
  end

  defp add_param(:request_path, params, conn),
    do: Map.put(params, :request_path, Phoenix.Controller.current_path(conn))

  defp add_param(:section, params, conn),
    do: Map.put(params, :section, get_section_slug(conn.assigns))

  defp get_section_slug(%{
         section: %Section{slug: section_slug}
       }),
       do: section_slug

  defp get_section_slug(%{section: section_slug}) when is_binary(section_slug),
    do: section_slug

  defp get_section_slug(_assigns), do: nil

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

  def path_for(conn, PowInvitation.Phoenix.InvitationController, :update, [token], query_params) do
    Routes.delivery_pow_invitation_invitation_path(conn, :update, token, query_params)
  end

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
