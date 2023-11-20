defmodule OliWeb.DirectedDiscussionChannel do
  use Phoenix.Channel
  alias Oli.Resources.Collaboration.Post
  alias Phoenix.PubSub

  def join("directed_discussion:" <> section_resource, _, socket) do
    case String.split(section_resource, ":") do
      [section_slug, resource_id] ->
        send(self(), {:after_join, {section_slug, resource_id}})
        {:ok, socket}

      _ ->
        {:error, %{reason: "unauthorized"}}
    end
  end

  def join(_, _params, _socket) do
    {:error, %{reason: "unauthorized"}}
  end

  def handle_info({:post_created, post, user_id}, socket) do
    push(socket, "post_created", %{post: Post.post_response(post), user_id: user_id})
    {:noreply, socket}
  end

  def handle_info({:post_deleted, post_id, user_id}, socket) do
    push(socket, "post_deleted", %{post_id: post_id, user_id: user_id})
    {:noreply, socket}
  end

  def handle_info({:after_join, {section_slug, resource_id}}, socket) do
    # TODO - we're subscribing to this topic, do we need to worry about someday unsubscribing after the last
    #        user leaves the channel?
    PubSub.subscribe(Oli.PubSub, collab_space_topic(section_slug, resource_id))
    {:noreply, socket}
  end

  def collab_space_topic(section_slug, resource_id),
    do: "collab_space_#{section_slug}_#{resource_id}"
end
