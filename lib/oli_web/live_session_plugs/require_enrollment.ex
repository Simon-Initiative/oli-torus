defmodule OliWeb.LiveSessionPlugs.RequireEnrollment do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias Oli.Delivery.Sections
  alias Oli.Accounts.{Author, SystemRole}

  def on_mount(:default, %{"section_slug" => section_slug}, _session, socket) do
    admin_system_role_id = SystemRole.role_id().admin

    case {socket.assigns[:current_user], socket.assigns[:current_author]} do
      {_, %Author{system_role_id: ^admin_system_role_id}} ->
        {:cont, assign(socket, is_enrolled: false)}

      {nil, _} ->
        # if this plug is checking for enrollment, we can infer that we are expecting a user to be already logged in
        {:halt, redirect(socket, to: ~p"/session/new?request_path=%2Fsections%2F#{section_slug}")}

      {user, _} ->
        is_enrolled = Sections.is_enrolled?(user.id, section_slug)

        if is_enrolled do
          {:cont, assign(socket, is_enrolled: is_enrolled)}
        else
          {:halt,
           socket
           |> put_flash(:error, "You are not enrolled in this course")
           |> redirect(to: ~p"/sections")}
        end
    end
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
