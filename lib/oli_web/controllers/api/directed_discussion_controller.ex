# API to support getting collaborative space discussions into the directed discussion activity.

defmodule OliWeb.Api.DirectedDiscussionController do
  @moduledoc """
  API endpoints for Directed Discussion activities.

  This controller handles creating, deleting, and retrieving discussion posts for
  Directed Discussion activities. It automatically evaluates activity attempts when
  participation requirements (minPosts, minReplies) are met, and resets attempts
  when requirements are no longer met (e.g., after post deletion).

  All evaluation and reset operations run asynchronously to avoid blocking the
  HTTP response.
  """
  use OliWeb, :controller
  use OpenApiSpex.Controller

  alias Oli.Repo
  alias Oli.Delivery.Sections

  alias Oli.Resources.Collaboration
  alias Phoenix.PubSub
  alias Oli.Resources.Collaboration.Post
  alias Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussion

  @doc """
  Creates a new discussion post for a Directed Discussion activity.

  After successfully creating the post, this endpoint asynchronously checks if
  participation requirements are met and evaluates the activity if so.

  ## Parameters
  - `resource_id`: The activity resource ID
  - `section_slug`: The course section identifier
  - `content`: The post message content (in request body)
  - `parent_post_id`: Optional parent post ID for replies (in request body)

  ## Response
  Returns the created post on success, or an error message if the user is not
  enrolled or post creation fails.
  """
  def create_post(conn, %{"resource_id" => resource_id, "section_slug" => section_slug}) do
    content = conn.body_params["content"]
    parent_post_id = Map.get(conn.body_params, "parent_post_id", nil)
    current_user = Map.get(conn.assigns, :current_user)
    section = Sections.get_section_by_slug(section_slug)
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    # Parse resource_id to integer if it's a string
    resource_id_int =
      case resource_id do
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
      end

    if Sections.is_enrolled?(current_user.id, section_slug) do
      Collaboration.create_post(%{
        status: :approved,
        user_id: current_user.id,
        section_id: section.id,
        resource_id: resource_id_int,
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
            topic_name(section_slug, resource_id_int),
            {:post_created, Repo.preload(post, :user), current_user.id}
          )

          # Check if participation requirements are met and evaluate if so
          # This runs asynchronously to avoid blocking the response
          Task.start(fn ->
            case DirectedDiscussion.evaluate_if_requirements_met(
                   section_slug,
                   section.id,
                   resource_id_int,
                   current_user.id,
                   datashop_session_id
                 ) do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                require Logger

                Logger.warning(
                  "Failed to evaluate Directed Discussion activity: #{inspect(reason)}"
                )
            end
          end)

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

  @doc """
  Deletes a discussion post.

  After successfully deleting the post, this endpoint asynchronously checks if
  participation requirements are still met. If not, it resets the activity attempt
  back to `:active` state.

  ## Parameters
  - `resource_id`: The activity resource ID
  - `section_slug`: The course section identifier
  - `post_id`: The ID of the post to delete

  ## Response
  Returns success if the post was deleted, or an error if the user doesn't own
  the post or is not enrolled.
  """
  def delete_post(conn, %{
        "resource_id" => resource_id,
        "section_slug" => section_slug,
        "post_id" => post_id
      }) do
    current_user = Map.get(conn.assigns, :current_user)

    # Parse resource_id to integer if it's a string
    resource_id_int =
      case resource_id do
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
      end

    {post_id, ""} = Integer.parse(post_id)

    post = Collaboration.get_post_by(%{id: post_id})
    section = Sections.get_section_by_slug(section_slug)

    if post.user_id == current_user.id and Sections.is_enrolled?(current_user.id, section_slug) do
      Collaboration.delete_posts(post)

      PubSub.broadcast(
        Oli.PubSub,
        topic_name(section_slug, resource_id_int),
        {:post_deleted, post_id, current_user.id}
      )

      # Check if participation requirements are still met after deletion
      # If not, reset the activity attempt back to :active
      Task.start(fn ->
        case DirectedDiscussion.reset_if_requirements_not_met(
               section.id,
               resource_id_int,
               current_user.id
             ) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            require Logger

            Logger.warning(
              "Failed to check/reset Directed Discussion activity after post deletion: #{inspect(reason)}"
            )
        end
      end)

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

  @doc """
  Retrieves all discussion posts for a user in a Directed Discussion activity.

  This endpoint asynchronously checks and updates the activity state:
  - If requirements are no longer met, resets the activity to `:active`
  - If requirements are met but not yet evaluated, evaluates the activity
  - If already evaluated and requirements still met, no action needed

  ## Parameters
  - `resource_id`: The activity resource ID
  - `section_slug`: The course section identifier

  ## Response
  Returns all posts for the current user in the specified activity, along with
  the current user ID.
  """
  def get_discussion(conn, %{"resource_id" => resource_id, "section_slug" => section_slug}) do
    current_user = Map.get(conn.assigns, :current_user)
    datashop_session_id = Plug.Conn.get_session(conn, :datashop_session_id)

    # Parse resource_id to integer if it's a string
    resource_id_int =
      case resource_id do
        id when is_binary(id) -> String.to_integer(id)
        id when is_integer(id) -> id
      end

    if Sections.is_enrolled?(current_user.id, section_slug) do
      section = Sections.get_section_by_slug(section_slug)

      posts =
        Collaboration.list_posts_for_user_in_page_section(
          section.id,
          resource_id_int,
          current_user.id
        )
        |> Enum.map(&Post.post_response/1)

      # Check if participation requirements are met and evaluate/reset if needed
      # This runs asynchronously to avoid blocking the response
      Task.start(fn ->
        # First check if we need to reset (if requirements are no longer met)
        case DirectedDiscussion.reset_if_requirements_not_met(
               section.id,
               resource_id_int,
               current_user.id
             ) do
          {:ok, :reset} ->
            :ok

          {:ok, :requirements_met} ->
            # Requirements are still met, check if we need to evaluate
            case DirectedDiscussion.evaluate_if_requirements_met(
                   section_slug,
                   section.id,
                   resource_id_int,
                   current_user.id,
                   datashop_session_id
                 ) do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                require Logger

                Logger.warning(
                  "Failed to evaluate Directed Discussion activity: #{inspect(reason)}"
                )
            end

          {:ok, :not_evaluated} ->
            # Activity not evaluated yet, check if we need to evaluate
            case DirectedDiscussion.evaluate_if_requirements_met(
                   section_slug,
                   section.id,
                   resource_id_int,
                   current_user.id,
                   datashop_session_id
                 ) do
              {:ok, _} ->
                :ok

              {:error, reason} ->
                require Logger

                Logger.warning(
                  "Failed to evaluate Directed Discussion activity: #{inspect(reason)}"
                )
            end

          {:error, reason} ->
            require Logger

            Logger.warning(
              "Failed to check/reset Directed Discussion activity: #{inspect(reason)}"
            )
        end
      end)

      json(conn, %{
        "result" => "success",
        "resource" => resource_id_int,
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
