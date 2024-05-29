defmodule OliWeb.LiveSessionPlugs.SetNotificationBadges do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Resources.Collaboration
  alias Oli.Publishing.DeliveryResolver

  def on_mount(
        :default,
        _params,
        _session,
        %{assigns: %{current_user: current_user, section: section}} = socket
      ) do
    {:cont,
     assign(socket, notification_badges: %{})
     |> maybe_load_discussions_badge(section, current_user)}
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}

  defp maybe_load_discussions_badge(socket, nil, _user), do: socket
  defp maybe_load_discussions_badge(socket, _section, nil), do: socket

  defp maybe_load_discussions_badge(socket, section, user) do
    # Load the discussions badge
    %{resource_id: root_curriculum_resource_id} =
      DeliveryResolver.root_container(section.slug)

    course_collab_space_config =
      Collaboration.get_course_collab_space_config(section.root_section_resource_id)

    course_discussions_enabled? =
      case course_collab_space_config do
        %Collaboration.CollabSpaceConfig{status: :enabled} -> true
        _ -> false
      end

    if course_discussions_enabled? do
      unread_replies_count =
        Collaboration.get_unread_replies_count_for_root_discussions(
          user.id,
          root_curriculum_resource_id
        )

      notification_badges = Map.get(socket.assigns, :notification_badges, %{})

      case unread_replies_count do
        0 ->
          socket

        _ ->
          assign(socket,
            notification_badges: Map.put(notification_badges, :discussions, unread_replies_count),
            has_unread_discussions: true
          )
      end
    else
      socket
    end
  end
end
