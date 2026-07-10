defmodule Oli.Scenarios.Directives.DiscussionModerationHandler do
  @moduledoc """
  Applies instructor moderation to named discussion posts.
  """

  alias Oli.Repo
  alias Oli.Delivery.Sections
  alias Oli.Resources.Collaboration
  alias Oli.Scenarios.DirectiveTypes.{DiscussionModerationDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(
        %DiscussionModerationDirective{
          post: post_name,
          instructor: instructor_name,
          action: action
        },
        %ExecutionState{} = state
      ) do
    with {:ok, instructor} <- fetch_user(state, instructor_name),
         {:ok, post} <- fetch_post(state, post_name),
         :ok <- authorize_moderation(instructor, post),
         {:ok, updated_post} <- moderate(post, action) do
      {:ok, Engine.put_discussion_post(state, post_name, updated_post)}
    else
      {:error, reason} ->
        {:error, "Failed to moderate discussion post: #{inspect(reason)}"}
    end
  end

  defp fetch_user(state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, "User '#{name}' not found"}
      user -> {:ok, user}
    end
  end

  defp authorize_moderation(instructor, post) do
    post = Repo.preload(post, :section)

    if post.section && Sections.is_instructor?(instructor, post.section.slug) do
      :ok
    else
      {:error, "User '#{instructor.email}' is not authorized to moderate this discussion post"}
    end
  end

  defp fetch_post(state, name) do
    case Engine.get_discussion_post(state, name) do
      nil ->
        {:error, "Discussion post '#{name}' not found"}

      post ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end

  defp moderate(post, :approve) do
    Collaboration.update_post(post, %{status: :approved})
  end

  defp moderate(post, :reject) do
    case Collaboration.delete_posts(post) do
      {count, nil} when count > 0 ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) |> Repo.preload(:user)}

      other ->
        {:error, other}
    end
  end
end
