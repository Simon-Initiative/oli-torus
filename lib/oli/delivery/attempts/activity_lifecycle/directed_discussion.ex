defmodule Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussion do
  @moduledoc """
  Helper functions for evaluating Directed Discussion activities based on participation requirements.
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ClientEvaluation}
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  @doc """
  Checks if participation requirements are met for a Directed Discussion activity.

  Returns `{:ok, true}` if requirements are met, `{:ok, false}` otherwise.
  Returns `{:error, reason}` if there's an issue checking requirements.
  """
  @spec check_participation_requirements(
          section_id :: integer(),
          resource_id :: integer(),
          user_id :: integer()
        ) :: {:ok, boolean()} | {:error, any()}
  def check_participation_requirements(section_id, resource_id, user_id) do
    # Get the latest activity attempt for this user and activity
    activity_attempt = get_latest_activity_attempt(section_id, user_id, resource_id)

    case activity_attempt do
      nil ->
        {:ok, false}

      %ActivityAttempt{} ->
        # Get the activity model to check participation requirements
        model = get_activity_model(activity_attempt)

        case model do
          nil ->
            {:error, "Could not retrieve activity model"}

          model ->
            participation = Map.get(model, "participation", %{})

            min_posts = Map.get(participation, "minPosts", 0)
            min_replies = Map.get(participation, "minReplies", 0)

            # Get all posts for this user in this resource
            posts =
              Collaboration.list_posts_for_user_in_page_section(
                section_id,
                resource_id,
                user_id
              )

            # Count posts and replies in a single pass
            {user_posts, user_replies} =
              Enum.reduce(posts, {0, 0}, fn post, {posts_count, replies_count} ->
                if is_nil(post.parent_post_id) do
                  {posts_count + 1, replies_count}
                else
                  {posts_count, replies_count + 1}
                end
              end)

            # Check if requirements are met
            posts_met = min_posts == 0 or user_posts >= min_posts
            replies_met = min_replies == 0 or user_replies >= min_replies

            {:ok, posts_met and replies_met}
        end
    end
  end

  @doc """
  Resets a Directed Discussion activity attempt if participation requirements are no longer met (for instance, if a post is deleted).

  This function:
  1. Gets the activity attempt
  2. Checks if participation requirements are still met
  3. If not met and the attempt was already evaluated, resets it back to :active state

  Returns `{:ok, :reset}` if reset was successful,
  `{:ok, :requirements_met}` if requirements are still met,
  `{:ok, :not_evaluated}` if not evaluated yet,
  or `{:error, reason}` if there's an error.
  """
  @spec reset_if_requirements_not_met(
          section_id :: integer(),
          resource_id :: integer(),
          user_id :: integer()
        ) :: {:ok, :reset | :requirements_met | :not_evaluated} | {:error, any()}
  def reset_if_requirements_not_met(section_id, resource_id, user_id) do
    # Get the latest activity attempt
    activity_attempt = get_latest_activity_attempt(section_id, user_id, resource_id)

    case activity_attempt do
      nil ->
        {:error, "Activity attempt not found"}

      %ActivityAttempt{
        lifecycle_state: lifecycle_state
      } ->
        # Only reset if the attempt was already evaluated/submitted
        if lifecycle_state == :evaluated or lifecycle_state == :submitted do
          # Check if requirements are still met
          case check_participation_requirements(section_id, resource_id, user_id) do
            {:ok, true} ->
              {:ok, :requirements_met}

            {:ok, false} ->
              # Reset the activity attempt back to :active
              reset_activity_attempt(activity_attempt)

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:ok, :not_evaluated}
        end
    end
  end

  defp reset_activity_attempt(%ActivityAttempt{} = activity_attempt) do
    # Reset the activity attempt and all its part attempts back to :active
    Repo.transaction(fn ->
      # Reset part attempts
      from(pa in Core.PartAttempt,
        where: pa.activity_attempt_id == ^activity_attempt.id
      )
      |> Repo.update_all(
        set: [lifecycle_state: :active, date_evaluated: nil, date_submitted: nil]
      )

      # Reset activity attempt
      case Core.update_activity_attempt(activity_attempt, %{
             lifecycle_state: :active,
             date_evaluated: nil,
             date_submitted: nil,
             score: nil,
             out_of: nil
           }) do
        {:ok, updated} ->
          # Update page progress after reset
          Oli.Delivery.Metrics.update_page_progress(activity_attempt.attempt_guid)
          updated

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, _} -> {:ok, :reset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Evaluates a Directed Discussion activity when participation requirements are met.

  This function:
  1. Gets the activity attempt
  2. Checks if participation requirements are met
  3. If met, evaluates the activity using client evaluation with score 1.0/1.0

  Returns `{:ok, :evaluated}` if evaluation was successful,
  `{:ok, :requirements_not_met}` if requirements aren't met yet,
  `{:ok, :already_evaluated}` if already evaluated,
  or `{:error, reason}` if there's an error.
  """
  @spec evaluate_if_requirements_met(
          section_slug :: String.t(),
          section_id :: integer(),
          resource_id :: integer(),
          user_id :: integer(),
          datashop_session_id :: String.t() | nil
        ) :: {:ok, :evaluated | :requirements_not_met | :already_evaluated} | {:error, any()}
  def evaluate_if_requirements_met(
        section_slug,
        section_id,
        resource_id,
        user_id,
        datashop_session_id \\ nil
      ) do
    # Get the latest activity attempt
    activity_attempt = get_latest_activity_attempt(section_id, user_id, resource_id)

    case activity_attempt do
      nil ->
        {:error, "Activity attempt not found"}

      %ActivityAttempt{
        lifecycle_state: lifecycle_state
      } ->
        # Evaluate if still active (regardless of attempt number, since each page attempt
        # creates new activity attempts with attempt_number=1 for that resource_attempt)
        if lifecycle_state == :active do
          # Check if requirements are met
          case check_participation_requirements(section_id, resource_id, user_id) do
            {:ok, true} ->
              # Requirements are met, evaluate the activity
              evaluate_activity(activity_attempt, section_slug, datashop_session_id)

            {:ok, false} ->
              {:ok, :requirements_not_met}

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:ok, :already_evaluated}
        end
    end
  end

  # Private helper functions

  defp get_latest_activity_attempt(section_id, user_id, resource_id) do
    # Get the latest activity attempt across ALL resource attempts for this user and activity
    # We need to find the latest one by looking at the resource_attempt's attempt_number
    # (which represents the page attempt number) and then the activity_attempt's attempt_number
    Repo.one(
      from(aa in ActivityAttempt,
        join: ra in Core.ResourceAttempt,
        on: ra.id == aa.resource_attempt_id,
        join: rac in Core.ResourceAccess,
        on: rac.id == ra.resource_access_id,
        left_join: aa2 in ActivityAttempt,
        on:
          aa2.resource_id == ^resource_id and
            aa2.resource_attempt_id == ra.id and
            aa.attempt_number < aa2.attempt_number,
        where:
          aa.resource_id == ^resource_id and
            rac.user_id == ^user_id and
            rac.section_id == ^section_id and
            is_nil(aa2.id),
        order_by: [desc: ra.attempt_number, desc: aa.attempt_number],
        limit: 1,
        select: aa,
        preload: [:revision, :resource_attempt]
      )
    )
  end

  defp get_activity_model(%ActivityAttempt{revision: revision}) do
    case revision do
      %{content: content} when is_map(content) ->
        content

      _ ->
        nil
    end
  end

  defp evaluate_activity(activity_attempt, section_slug, datashop_session_id) do
    # Get part attempts for this activity
    part_attempts = Core.get_latest_part_attempts(activity_attempt.attempt_guid)

    case part_attempts do
      [] ->
        {:error, "No part attempts found for activity"}

      _ ->
        # Create client evaluations for each part attempt
        # For Directed Discussion, we mark it as complete with score 1.0/1.0
        client_evaluations =
          Enum.map(part_attempts, fn part_attempt ->
            %{
              attempt_guid: part_attempt.attempt_guid,
              client_evaluation: %ClientEvaluation{
                score: 1.0,
                out_of: 1.0,
                feedback: nil,
                input: nil,
                timestamp: DateTime.utc_now()
              }
            }
          end)

        # Apply client evaluation
        # Use enforce_client_side_eval: false since this is server-side evaluation
        # triggered by server-side logic (post creation), not client-side evaluation
        case Evaluate.apply_client_evaluation(
               section_slug,
               activity_attempt.attempt_guid,
               client_evaluations,
               datashop_session_id,
               enforce_client_side_eval: false
             ) do
          {:ok, _} ->
            {:ok, :evaluated}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end
end
