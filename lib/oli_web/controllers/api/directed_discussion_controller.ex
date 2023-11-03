# API to support getting collaborative space discussions into the directed discussion activity.

defmodule OliWeb.Api.DirectedDiscussionController do
  @moduledoc """
  Provides user state service endpoints for extrinsic state.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Delivery.Sections

  alias Oli.Resources.Collaboration
  alias OliWeb.Api.State

  def get_discussion(conn, %{"resource_id" => resource_id, "section_slug" => section_slug}) do
    section = Sections.get_section_by_slug(section_slug)
    current_user = Map.get(conn.assigns, :current_user)

    posts =
      Collaboration.list_posts_for_user_in_page_section(
        section.id,
        resource_id,
        current_user.id
      )
      |> Enum.map(&post_response/1)

    json(conn, %{
      "result" => "success",
      "resource" => resource_id,
      "section" => section_slug,
      "posts" => posts
    })
  end

  defp post_response(post) do
    IO.inspect(post)

    %{
      id: post.id,
      content: post.content.message,
      user_id: post.user_id,
      user_name: post.user.name,
      parent_post_id: post.parent_post_id,
      thread_root_id: post.thread_root_id,
      replies_count: post.replies_count,
      anonymous: post.anonymous,
      updated_at: post.updated_at
    }
  end
end
