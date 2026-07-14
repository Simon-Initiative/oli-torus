defmodule Oli.Scenarios.Directives.DiscussionDeleteHandler do
  @moduledoc """
  Deletes named discussion posts through the collaboration authorization path.
  """

  alias Oli.Delivery.Sections
  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Scenarios.DirectiveTypes.{DiscussionDeleteDirective, ExecutionState}
  alias Oli.Scenarios.Engine

  def handle(
        %DiscussionDeleteDirective{post: post_name, actor: actor_name},
        %ExecutionState{} = state
      ) do
    with {:ok, actor} <- fetch_user(state, actor_name),
         {:ok, post} <- fetch_post(state, post_name),
         :ok <- authorize_delete(actor, post),
         {count, nil} when count > 0 <- Collaboration.soft_delete_post(post.id, actor),
         updated_post <- Collaboration.get_post_by(%{id: post.id}) |> Repo.preload(:user) do
      {:ok, Engine.put_discussion_post(state, post_name, updated_post)}
    else
      {:error, reason} ->
        {:error, "Failed to delete discussion post: #{inspect(reason)}"}

      other ->
        {:error, "Failed to delete discussion post: #{inspect(other)}"}
    end
  end

  defp fetch_user(state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, "User '#{name}' not found"}
      user -> {:ok, user}
    end
  end

  defp authorize_delete(actor, post) do
    post = Repo.preload(post, :section)

    cond do
      post.user_id == actor.id ->
        :ok

      post.section && Sections.is_instructor?(actor, post.section.slug) ->
        :ok

      true ->
        {:error, "User '#{actor.email}' is not authorized to delete this discussion post"}
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
end
