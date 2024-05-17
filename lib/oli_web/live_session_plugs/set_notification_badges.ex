defmodule OliWeb.LiveSessionPlugs.SetNotificationBadges do
  use OliWeb, :verified_routes

  import Phoenix.Component, only: [assign: 2]

  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration
  alias Oli.Publishing.DeliveryResolver

  def on_mount(:default, _params, _session, socket) do
    %{current_user: current_user, section: section} = socket.assigns

    badges =
      %{}
      |> load_discussions_badge(section, current_user)
      |> dbg()

    dbg(badges)

    {:cont, assign(socket, notification_badges: badges)}
  end

  defp load_discussions_badge(badges, _, user) when is_nil(user), do: badges

  defp load_discussions_badge(badges, section, user) do
    # Load the discussions badge
    %{resource_id: root_curriculum_resource_id} =
      DeliveryResolver.root_container(section.slug)

    unread_replies_count =
      Collaboration.get_unread_reply_counts_for_root_discussions(
        user.id,
        root_curriculum_resource_id
      )
      |> Enum.reduce(0, fn %{count: count}, acc -> acc + count end)

    case unread_replies_count do
      0 -> badges
      _ -> Map.put(badges, :discussions, unread_replies_count)
    end
  end
end
