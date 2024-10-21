defmodule OliWeb.LaunchController do
  use OliWeb, :controller
  use OliWeb, :verified_routes

  alias Oli.{Accounts, Repo}
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Publishing.DeliveryResolver
  alias Lti_1p3.DataProviders.EctoProvider.Marshaler
  alias Lti_1p3.Tool.{PlatformRoles, ContextRoles}
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.UserAuth

  def join(conn, %{"section_slug" => section_slug}) do
    section = conn.assigns.section
    current_user = conn.assigns.current_user

    case section do
      %Section{open_and_free: true, requires_enrollment: false} ->
        params = %{auto_enroll_as_guest: is_nil(current_user) || current_user.guest}

        conn
        |> redirect(to: ~p"/sections/#{section_slug}/enroll?#{params}")

      _ ->
        conn
        |> redirect(to: Routes.static_page_path(OliWeb.Endpoint, :unauthorized))
    end
  end

  def auto_enroll_as_guest(conn, params) do
    g_recaptcha_response = Map.get(params, "g-recaptcha-response", "")

    if Oli.Utils.LoadTesting.enabled?() or recaptcha_verified?(g_recaptcha_response) do
      with {:available, section} <- Sections.available?(conn.assigns.section),
           {:ok, user} <- current_or_guest_user(conn, section.requires_enrollment),
           user <- Repo.preload(user, [:platform_roles]) do
        first_page_slug = DeliveryResolver.get_first_page_slug(section.slug)
        first_page_url = ~p"/sections/#{section.slug}/page/#{first_page_slug}"

        if Sections.is_enrolled?(user.id, section.slug) do
          redirect(conn,
            to: first_page_url
          )
        else
          Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
          Sections.mark_section_visited_for_student(section, user)

          Accounts.update_user_platform_roles(
            user,
            Marshaler.from(user.platform_roles)
            |> MapSet.new()
            |> MapSet.put(PlatformRoles.get_role(:institution_learner))
            |> MapSet.to_list()
          )

          conn
          |> UserAuth.log_in_user(user)
          |> redirect(to: first_page_url)
        end
      else
        {:redirect, nil} ->
          # guest user cant access courses that require enrollment
          redirect_path =
            "/users/log_in?request_path=#{Routes.delivery_path(conn, :show_enroll, conn.assigns.section.slug)}"

          conn
          |> put_flash(
            :error,
            "Cannot enroll guest users in a course section that requires enrollment"
          )
          |> redirect(to: redirect_path)

        _error ->
          render(conn, "enroll.html", error: "Something went wrong, please try again")
      end
    else
      render(conn, "enroll.html", error: "ReCaptcha failed, please try again")
    end
  end

  defp recaptcha_verified?(g_recaptcha_response) do
    Oli.Utils.Recaptcha.verify(g_recaptcha_response) == {:success, true}
  end

  defp current_or_guest_user(conn, requires_enrollment) do
    case conn.assigns.current_user do
      nil ->
        if requires_enrollment, do: {:redirect, nil}, else: Accounts.create_guest_user()

      %User{guest: true} = guest ->
        if requires_enrollment, do: {:redirect, nil}, else: {:ok, guest}

      user ->
        {:ok, user}
    end
  end
end
