defmodule Oli.Scenarios.Directives.PostReactionHandler do
  @moduledoc """
  Deterministically adds or removes reactions on named collaboration posts.
  """

  alias Oli.Resources.Collaboration
  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, PostReactionDirective}
  alias Oli.Scenarios.Engine

  def handle(
        %PostReactionDirective{
          post: post_name,
          student: student_name,
          reaction: reaction,
          action: action
        },
        %ExecutionState{} = state
      ) do
    with {:ok, post} <- fetch_post(state, post_name),
         {:ok, student} <- fetch_user(state, student_name),
         :ok <- apply_action(post.id, student.id, reaction, action) do
      {:ok, state}
    else
      {:error, reason} ->
        {:error, "Failed to update post reaction: #{inspect(reason)}"}
    end
  end

  defp fetch_post(state, name) do
    case Engine.get_collaboration_post(state, name) do
      nil ->
        {:error, "Collaboration post '#{name}' not found"}

      post ->
        {:ok, Collaboration.get_post_by(%{id: post.id}) || post}
    end
  end

  defp fetch_user(state, name) do
    case Engine.get_user(state, name) do
      nil -> {:error, "User '#{name}' not found"}
      user -> {:ok, user}
    end
  end

  defp apply_action(post_id, user_id, reaction, :add) do
    post_id
    |> Collaboration.add_reaction(user_id, reaction)
    |> normalize_result()
  end

  defp apply_action(post_id, user_id, reaction, :remove) do
    post_id
    |> Collaboration.remove_reaction(user_id, reaction)
    |> normalize_result()
  end

  defp normalize_result({:ok, _change}), do: :ok
end
