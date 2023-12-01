# API to support getting collaborative space discussions into the directed discussion activity.

defmodule OliWeb.Api.DirectedDiscussionController do
  @moduledoc """
  Provides user state service endpoints for extrinsic state.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Repo
  alias Oli.Delivery.Sections

  alias Oli.Resources.Collaboration
  alias Phoenix.PubSub
  alias Oli.Resources.Collaboration.Post

  def create_post(conn, %{"resource_id" => resource_id, "section_slug" => section_slug}) do
    content = conn.body_params["content"]
    parent_post_id = Map.get(conn.body_params, "parent_post_id", nil)
    current_user = Map.get(conn.assigns, :current_user)
    section = Sections.get_section_by_slug(section_slug)

    if Sections.is_enrolled?(current_user.id, section_slug) do
      Collaboration.create_post(%{
        status: :approved,
        user_id: current_user.id,
        section_id: section.id,
        resource_id: resource_id,
        parent_post_id: parent_post_id,
        thread_root_id: parent_post_id,
        replies_count: 0,
        anonymous: false,
        content: %{"message" => content}
      })
      |> preload_post_user
      |> case do
        {:ok, post} ->
          PubSub.broadcast(
            Oli.PubSub,
            topic_name(section_slug, resource_id),
            {:post_created, Repo.preload(post, :user), current_user.id}
          )

          json(conn, %{
            "result" => "success",
            "post" => Post.post_response(post)
          })

        error ->
          json(conn, %{
            "result" => "failure",
            "error" => error
          })
      end
    else
      json(conn, %{
        "result" => "failure",
        "error" => "User does not have permission to create a post."
      })
    end
  end

  defp topic_name(project_slug, resource_id) do
    "collab_space_#{project_slug}_#{resource_id}"
  end

  def delete_post(conn, %{
        "resource_id" => resource_id,
        "section_slug" => section_slug,
        "post_id" => post_id
      }) do
    current_user = Map.get(conn.assigns, :current_user)

    {post_id, ""} = Integer.parse(post_id)

    post = Collaboration.get_post_by(%{id: post_id})

    if post.user_id == current_user.id and Sections.is_enrolled(current_user.id, section_slug) do
      Collaboration.delete_posts(post)

      PubSub.broadcast(
        Oli.PubSub,
        topic_name(section_slug, resource_id),
        {:post_deleted, post_id, current_user.id}
      )

      json(conn, %{
        "result" => "success"
      })
    else
      json(conn, %{
        "result" => "failure",
        "error" => "User does not have permission to delete this post."
      })
    end
  end

  defp preload_post_user({:ok, post}), do: {:ok, Repo.preload(post, :user)}
  defp preload_post_user(error), do: error

  def get_discussion(conn, %{"resource_id" => resource_id, "section_slug" => section_slug}) do
    current_user = Map.get(conn.assigns, :current_user)

    if Sections.is_enrolled?(current_user.id, section_slug) do
      section = Sections.get_section_by_slug(section_slug)

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          resource_id,
          current_user.id
        )
        |> Enum.map(&Post.post_response/1)

      json(conn, %{
        "result" => "success",
        "resource" => resource_id,
        "section" => section_slug,
        "posts" => posts,
        "current_user" => current_user.id
      })
    else
      json(conn, %{
        "result" => "failure",
        "error" => "User does not have permission to view these posts."
      })
    end
  end
end
