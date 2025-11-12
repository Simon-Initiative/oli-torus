defmodule OliWeb.LiveSessionPlugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  @suspended_message "Your access to this course has been suspended. Please contact your instructor."

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    is_admin? = Oli.Accounts.is_admin?(socket.assigns[:current_author])

    case {socket.assigns[:current_user], is_admin?} do
      {_, true} ->
        {:cont, assign(socket, is_enrolled: true)}

      {nil, _} ->
        # If this plug is checking for enrollment, we can infer that we are expecting a user to be already logged in
        {:halt,
         redirect(socket, to: ~p"/users/log_in?request_path=%2Fsections%2F#{section_slug}")}

      {user, _} ->
        section =
          case socket.assigns[:section] do
            %Section{} = s -> s
            _ -> Sections.get_section_by(slug: section_slug)
          end

        enrollment =
          Sections.get_enrollment(section_slug, user.id, filter_by_status: false)

        cond do
          enrolled?(enrollment, section) ->
            {:cont, assign(socket, is_enrolled: true)}

          section.registration_open && suspended?(enrollment) ->
            {:halt,
             socket
             |> put_flash(:error, @suspended_message)
             |> redirect(to: ~p"/users/log_in?request_path=%2Fsections%2F#{section.slug}")}

          section.registration_open ->
            {:halt,
             socket
             |> redirect(to: ~p"/sections/#{section.slug}/enroll")}

          true ->
            {:halt,
             socket
             |> put_flash(:error, "You are not enrolled in this course")
             |> redirect(to: ~p"/workspaces/student")}
        end
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end

  defp enrolled?(%{status: :enrolled}, %{status: :active}), do: true
  defp enrolled?(_, _), do: false

  defp suspended?(%{status: :suspended}), do: true
  defp suspended?(_), do: false
end
