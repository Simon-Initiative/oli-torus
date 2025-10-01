defmodule OliWeb.LiveSessionPlugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles

  def on_mount(
        :default,
        _params,
        _session,
        %{
          assigns: %{
            current_user: user,
            section: %Sections.Section{requires_enrollment: false} = section
          }
        } = socket
      )
      when not is_nil(user) do
    if user do
      if !Sections.has_enrollment?(user.id, section.slug) do
        Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])
      end
    end

    {:cont, assign(socket, is_enrolled: true)}
  end

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
        is_enrolled = Sections.is_enrolled?(user.id, section_slug)

        if is_enrolled do
          {:cont, assign(socket, is_enrolled: is_enrolled)}
        else
          # Section should already be assigned by the SetSection plug, but if not, fetch it
          section =
            case socket.assigns[:section] do
              %Section{} = s -> s
              _ -> Sections.get_section_by(slug: section_slug)
            end

          # If the section registration is open, redirect to enrollment page
          # otherwise, redirect to student workspace with error message
          if section.registration_open do
            {:halt,
             socket
             |> redirect(to: ~p"/sections/#{section.slug}/enroll")}
          else
            {:halt,
             socket
             |> put_flash(:error, "You are not enrolled in this course")
             |> redirect(to: ~p"/workspaces/student")}
          end
        end
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
