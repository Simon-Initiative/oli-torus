defmodule OliWeb.LiveSessionPlugs.SetNotificationBadges do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration

  def on_mount(:default, _params, _session, socket) do
    %{current_user: current_user, section: section} = socket.assigns

    badges =
      %{}
      |> load_discussions_badge(section, current_user)

    dbg(badges)

    {:cont, assign(socket, notification_badges: badges)}
  end

  defp load_discussions_badge(badges, _, user) when is_nil(user), do: badges

  defp load_discussions_badge(badges, section, user) do
    # Load the discussions badge
    root_section_resource_resource_id =
      Sections.get_root_section_resource_resource_id(section)

    unread_replies_count =
      Collaboration.get_unread_reply_counts_for_root_discussions(
        user.id,
        root_section_resource_resource_id
      )
      |> Enum.reduce(0, fn %{count: count}, acc -> acc + count end)

    case unread_replies_count do
      0 -> badges
      _ -> Map.put(badges, :discussions, unread_replies_count)
    end
  end
end
