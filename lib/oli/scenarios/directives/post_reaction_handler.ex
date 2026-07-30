defmodule Oli.Scenarios.Directives.PostReactionHandler do
  @moduledoc """
  Deterministically adds or removes reactions on named annotation or discussion posts.

  This is scenario-only mutation support. The reacting user and target post are resolved from
  trusted scenario execution state rather than from production request parameters.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Resources.Collaboration.UserReactionPost
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
    case Engine.get_named_post(state, name) do
      nil ->
        {:error, "Annotation or discussion post '#{name}' not found"}

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
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      UserReactionPost,
      [
        %{
          post_id: post_id,
          user_id: user_id,
          reaction: reaction,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing,
      conflict_target: [:reaction, :post_id, :user_id]
    )

    :ok
  end

  defp apply_action(post_id, user_id, reaction, :remove) do
    UserReactionPost
    |> where(
      [r],
      r.post_id == ^post_id and r.user_id == ^user_id and r.reaction == ^reaction
    )
    |> Repo.delete_all()

    :ok
  end
end
