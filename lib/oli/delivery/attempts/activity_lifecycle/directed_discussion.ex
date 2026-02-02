defmodule Oli.Delivery.Attempts.ActivityLifecycle.DirectedDiscussion do
  @moduledoc """
  Specialized evaluation logic for Directed Discussion activities.

  This module implements activity type specialization for Directed Discussion activities,
  which have unique evaluation requirements based on participation (posts and replies).
  When a Directed Discussion activity is evaluated through the main `evaluate_activity/5`
  function in `Oli.Delivery.Attempts.ActivityLifecycle.Evaluate`, it delegates to this
  module's `evaluate_activity/5` function.

  The evaluation process:
  1. Checks if participation requirements (min posts/replies) are met
  2. If met, evaluates the activity with a score of 1.0/1.0
  3. Routes through the standard evaluation infrastructure (RollUp, Metrics, Snapshots)
  4. Generates xAPI statements for OLAP ingestion
  """

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Collaboration
  alias Oli.Delivery.Attempts.Core

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    ClientEvaluation,
    ResourceAttempt,
    ResourceAccess
  }

  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.ApplyClientEvaluation

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

            # Count posts and replies using DB-side aggregation for efficiency
            {user_posts, user_replies} =
              Collaboration.count_posts_and_replies_for_user(section_id, resource_id, user_id)

            # Check if requirements are met
            posts_met = min_posts == 0 or user_posts >= min_posts
            replies_met = min_replies == 0 or user_replies >= min_replies

            {:ok, posts_met and replies_met}
        end
    end
  end

  @doc """
  Creates a new activity attempt if the latest attempt is evaluated/submitted and
  participation requirements are no longer met (e.g., after a post is deleted).

  This function only creates a new attempt if the current attempt is in `:evaluated` or
  `:submitted` state. If the attempt is still `:active` (not yet evaluated), it returns
  `{:ok, :not_evaluated}` without creating a new attempt, allowing the student to continue
  working on the existing attempt.

  Behavior:
  - If the attempt is `:evaluated` or `:submitted` and requirements are NOT met:
    Creates a new activity attempt with incremented attempt_number, leaving the old
    evaluated attempt unchanged (to maintain system invariants).
  - If the attempt is `:evaluated` or `:submitted` and requirements ARE still met:
    Returns `{:ok, :requirements_met}` - no action needed.
  - If the attempt is `:active` (not yet evaluated):
    Returns `{:ok, :not_evaluated}` - no new attempt needed, student can continue.

  Returns:
  - `{:ok, :new_attempt_created}` - A new attempt was created (old evaluated attempt remains unchanged)
  - `{:ok, :requirements_met}` - Requirements are still met, no action needed
  - `{:ok, :not_evaluated}` - Attempt is still active, no new attempt needed
  - `{:error, reason}` - An error occurred

  Note: The old evaluated attempt is left unchanged to maintain system invariants
  (evaluated attempts should never be modified). This ensures xAPI statements and
  OLAP ingestion remain consistent.
  """
  @spec create_new_attempt_if_evaluated_and_requirements_not_met(
          section_slug :: String.t(),
          section_id :: integer(),
          resource_id :: integer(),
          user_id :: integer(),
          datashop_session_id :: String.t() | nil
        ) ::
          {:ok, :new_attempt_created | :requirements_met | :not_evaluated}
          | {:error, any()}
  def create_new_attempt_if_evaluated_and_requirements_not_met(
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
        # Only create new attempt if the current one was already evaluated/submitted
        if lifecycle_state == :evaluated or lifecycle_state == :submitted do
          # Check if requirements are still met
          case check_participation_requirements(section_id, resource_id, user_id) do
            {:ok, true} ->
              {:ok, :requirements_met}

            {:ok, false} ->
              # Requirements are not met, create a new attempt using the centralized reset_activity function
              # This reuses the existing infrastructure for creating new attempts
              case ActivityLifecycle.reset_activity(
                     section_slug,
                     activity_attempt.attempt_guid,
                     datashop_session_id,
                     false,
                     nil
                   ) do
                {:ok, _} ->
                  {:ok, :new_attempt_created}

                {:error, {:not_found}} ->
                  {:error, "Activity attempt not found"}

                {:error, {:already_reset}} ->
                  # This shouldn't happen since we just got the latest attempt,
                  # but handle it gracefully
                  {:ok, :new_attempt_created}

                {:error, {:no_more_attempts}} ->
                  {:error, "Maximum attempts reached"}

                {:error, reason} ->
                  {:error, reason}
              end

            {:error, reason} ->
              {:error, reason}
          end
        else
          {:ok, :not_evaluated}
        end
    end
  end

  @doc """
  Evaluates a Directed Discussion activity attempt.

  This is the specialized evaluation function for Directed Discussion activities, called
  by the main `evaluate_activity/5` function when the activity type is `oli_directed_discussion`.

  The function:
  1. Extracts section_id, user_id, and resource_id from the activity attempt structure
  2. Checks if the attempt is still `:active` (if already evaluated, returns empty results)
  3. Checks if participation requirements (min posts/replies) are met
  4. If requirements are met, evaluates the activity using client evaluation with score 1.0/1.0
  5. Routes through the proper evaluation infrastructure (RollUp, Metrics, Snapshots)
  6. Generates and emits xAPI statements for OLAP ingestion

  Note: The `part_inputs` parameter may be empty `[]` for Directed Discussion activities,
  as evaluation is based on participation requirements rather than traditional part inputs.

  ## Parameters
  - `section_slug`: The section slug
  - `activity_attempt_guid`: The GUID of the activity attempt to evaluate
  - `part_inputs`: List of part inputs (may be empty for Directed Discussion)
  - `datashop_session_id`: Optional datashop session ID

  ## Returns
  - `{:ok, [map()]}` - Evaluation results (list of evaluation result maps)
  - `{:ok, []}` - If requirements not met yet or already evaluated (empty results)
  - `{:error, reason}` - If an error occurred

  The evaluation results follow the same format as standard evaluation:
  `%{score: score, out_of: out_of, feedback: feedback, attempt_guid: attempt_guid}`
  """
  @spec evaluate_activity(
          section_slug :: String.t(),
          activity_attempt_guid :: String.t(),
          part_inputs :: [map()],
          datashop_session_id :: String.t() | nil
        ) :: {:ok, [map()]} | {:error, any()}
  def evaluate_activity(section_slug, activity_attempt_guid, _part_inputs, datashop_session_id) do
    # Get activity attempt with proper preloading
    activity_attempt =
      Core.get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload(resource_attempt: [:resource_access], revision: [:activity_type])

    case activity_attempt do
      nil ->
        {:error, "Activity attempt not found"}

      %ActivityAttempt{
        resource_attempt:
          %ResourceAttempt{
            resource_access: %ResourceAccess{
              section_id: section_id,
              user_id: user_id
            }
          } = _resource_attempt,
        resource_id: resource_id,
        lifecycle_state: lifecycle_state
      } ->
        # Only evaluate if still active
        case lifecycle_state do
          :active ->
            # Check if participation requirements are met
            case check_participation_requirements(section_id, resource_id, user_id) do
              {:ok, true} ->
                # Requirements met - proceed with evaluation
                # Get part attempts for this activity
                part_attempts = Core.get_latest_part_attempts(activity_attempt_guid)

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

                    # Apply client evaluation using the centralized evaluation infrastructure.
                    # This ensures proper rollup, metrics updates, and xAPI statement generation.

                    ApplyClientEvaluation.apply(
                      section_slug,
                      activity_attempt_guid,
                      client_evaluations,
                      datashop_session_id,
                      enforce_client_side_eval: false
                    )
                end

              {:ok, false} ->
                # Requirements not met yet, return empty results
                {:ok, []}

              {:error, reason} ->
                {:error, reason}
            end

          _ ->
            # Already evaluated/submitted, return empty results
            {:ok, []}
        end
    end
  end

  @doc """
  Evaluates a Directed Discussion activity when participation requirements are met.

  This is a convenience function that looks up the latest activity attempt using
  `section_id`, `resource_id`, and `user_id`, then calls the main `evaluate_activity/5`
  function. Use this when you have these IDs but not the `activity_attempt_guid`.

  The evaluation process:
  - Routes through the proper evaluation infrastructure (RollUp, Metrics, Snapshots)
  - Generates and emits xAPI statements for OLAP ingestion
  - Updates page progress metrics
  - Ensures the attempt is properly marked as evaluated

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
        attempt_guid: activity_attempt_guid,
        lifecycle_state: lifecycle_state
      } ->
        # Evaluate if still active (regardless of attempt number, since each page attempt
        # creates new activity attempts with attempt_number=1 for that resource_attempt)
        if lifecycle_state == :active do
          # Call the main evaluate_activity/5 function
          case evaluate_activity(section_slug, activity_attempt_guid, [], datashop_session_id) do
            {:ok, []} ->
              # Empty results means requirements not met yet
              {:ok, :requirements_not_met}

            {:ok, _results} ->
              # Non-empty results means evaluation succeeded
              {:ok, :evaluated}

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
end
