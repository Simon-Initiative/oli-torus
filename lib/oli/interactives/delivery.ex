defmodule Oli.Interactives.Delivery do
  @moduledoc """
  Learner-facing Interactive capabilities. Identifiers and authorization remain in Torus;
  generated apps use stable manifest part IDs and JSON values through the iframe SDK.
  """

  import Ecto.Query

  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.{ApplyClientEvaluation, RollUp}
  alias Oli.Delivery.Attempts.Core, as: Attempts

  alias Oli.Delivery.Attempts.Core.{
    ActivityAttempt,
    ClientEvaluation,
    ResourceAttempt,
    StudentInput
  }

  alias Oli.Delivery.{ExtrinsicState, Metrics, Sections}
  alias Oli.Repo

  @reads ["context", "attempt.get", "section.get"]

  @doc """
  Executes a version 1 SDK request for the learner's own Interactive attempt.
  For sections that explicitly allow delivery without enrollment, initializes the
  learner enrollment needed for section-scoped state after verifying attempt ownership.
  """
  def execute(user_id, section_slug, attempt_guid, request, datashop_session_id \\ nil) do
    Repo.transaction(fn ->
      attempt =
        Repo.one(
          from(a in ActivityAttempt,
            join: r in assoc(a, :resource_attempt),
            join: access in assoc(r, :resource_access),
            join: section in assoc(access, :section),
            join: revision in assoc(a, :revision),
            join: type in assoc(revision, :activity_type),
            where:
              a.attempt_guid == ^attempt_guid and access.user_id == ^user_id and
                section.slug == ^section_slug and type.slug == "oli_interactive",
            lock: fragment("FOR UPDATE OF ?", a)
          )
        )

      enrollment = enrollment_for_attempt(attempt, section_slug, user_id)

      case {attempt, enrollment, request} do
        {%ActivityAttempt{}, %{status: :enrolled}, %{"version" => 1, "method" => method}} ->
          writable = writable?(attempt)

          case method in @reads or writable do
            true ->
              dispatch(attempt, enrollment, section_slug, request, datashop_session_id)

            false when method == "activity.finalize" and attempt.lifecycle_state == :evaluated ->
              context(attempt, false)

            false ->
              Repo.rollback(:read_only)
          end

        {nil, _, _} ->
          Repo.rollback(:not_found)

        {_, %{status: status}, _} when status != :enrolled ->
          Repo.rollback(:not_found)

        {_, nil, _} ->
          Repo.rollback(:not_found)

        _ ->
          Repo.rollback(:invalid_request)
      end
    end)
  end

  defp enrollment_for_attempt(attempt, section_slug, user_id) do
    case {Sections.get_enrollment(section_slug, user_id, filter_by_status: false), attempt} do
      {nil, %ActivityAttempt{}} ->
        case Sections.get_section_by_slug(section_slug) do
          %{requires_enrollment: false, status: :active, id: section_id} ->
            role = Lti_1p3.Roles.ContextRoles.get_role(:context_learner)

            case Sections.enroll(user_id, section_id, [role]) do
              {:ok, enrollment} -> enrollment
              _ -> nil
            end

          _ ->
            nil
        end

      {enrollment, _} ->
        enrollment
    end
  end

  defp writable?(attempt) do
    page = Repo.get!(ResourceAttempt, attempt.resource_attempt_id)
    latest = Attempts.get_latest_activity_attempt(page.id, attempt.resource_id)

    latest_page =
      Repo.one(
        from(r in ResourceAttempt,
          where: r.resource_access_id == ^page.resource_access_id,
          order_by: [desc: r.attempt_number],
          limit: 1
        )
      )

    attempt.lifecycle_state == :active and page.lifecycle_state == :active and
      latest.id == attempt.id and latest_page.id == page.id
  end

  defp dispatch(attempt, _, _, %{"method" => "context"}, _) do
    context(attempt, writable?(attempt))
  end

  defp dispatch(attempt, enrollment, slug, %{"method" => method, "params" => params}, _)
       when method in ["attempt.get", "section.get", "attempt.set", "section.set"] and
              is_map(params) do
    key = params["key"]

    case is_binary(key) and byte_size(key) in 1..256 do
      false ->
        Repo.rollback(:invalid_request)

      true ->
        keys = MapSet.new([key])

        result =
          case method do
            "attempt.get" ->
              ExtrinsicState.read_activity(attempt.attempt_guid, keys)

            "section.get" ->
              ExtrinsicState.read_section(enrollment.user_id, slug, keys)

            "attempt.set" ->
              validate_value!(params)
              ExtrinsicState.upsert_activity(attempt.attempt_guid, %{key => params["value"]})

            "section.set" ->
              validate_value!(params)
              # Different Interactives can update the same enrollment concurrently.
              Repo.one!(
                from(e in Oli.Delivery.Sections.Enrollment,
                  where: e.id == ^enrollment.id,
                  lock: "FOR UPDATE"
                )
              )

              ExtrinsicState.upsert_section(enrollment.user_id, slug, %{key => params["value"]})
          end

        case result do
          {:ok, state} -> Map.get(state, key)
          {:error, _} -> Repo.rollback(:state_failed)
        end
    end
  end

  defp dispatch(
         attempt,
         _,
         slug,
         %{
           "method" => "parts.finalize",
           "params" => %{
             "partId" => part_id,
             "response" => response,
             "correct" => correct
           }
         },
         session_id
       )
       when is_binary(part_id) and is_boolean(correct) do
    part =
      Enum.find(Attempts.get_latest_part_attempts(attempt.attempt_guid), &(&1.part_id == part_id))

    case part do
      nil ->
        Repo.rollback(:unknown_part)

      part ->
        case part.lifecycle_state do
          :evaluated ->
            case ActivityLifecycle.reset_part(attempt.attempt_guid, part.attempt_guid, session_id) do
              {:ok, _} -> :ok
              {:error, _} -> Repo.rollback(:evaluation_failed)
            end

          :active ->
            :ok

          _ ->
            Repo.rollback(:read_only)
        end

        latest =
          Enum.find(
            Attempts.get_latest_part_attempts(attempt.attempt_guid),
            &(&1.part_id == part_id)
          )

        evaluation = %{
          attempt_guid: latest.attempt_guid,
          client_evaluation: %ClientEvaluation{
            input: %StudentInput{input: response},
            score:
              case correct do
                true -> 1
                false -> 0
              end,
            out_of: 1,
            feedback: nil
          }
        }

        case ApplyClientEvaluation.apply(slug, attempt.attempt_guid, [evaluation], session_id,
               no_roll_up: true
             ) do
          {:ok, _} -> context(attempt, true)
          {:error, _} -> Repo.rollback(:evaluation_failed)
        end
    end
  end

  defp dispatch(attempt, _, _, %{"method" => "activity.finalize"}, _) do
    parts = Attempts.get_latest_part_attempts(attempt.attempt_guid)

    case parts != [] and Enum.all?(parts, &(&1.lifecycle_state == :evaluated)) do
      true ->
        case RollUp.rollup_evaluated(attempt.attempt_guid) do
          :ok ->
            Metrics.update_page_progress(attempt.attempt_guid)
            context(Attempts.get_activity_attempt_by(attempt_guid: attempt.attempt_guid), false)

          _ ->
            Repo.rollback(:evaluation_failed)
        end

      false ->
        Repo.rollback(:incomplete_parts)
    end
  end

  defp dispatch(_, _, _, _, _), do: Repo.rollback(:invalid_request)

  defp validate_value!(params) do
    case Map.has_key?(params, "value") and byte_size(Jason.encode!(params["value"])) <= 1_000_000 do
      true -> :ok
      false -> Repo.rollback(:invalid_request)
    end
  end

  defp context(attempt, writable) do
    %{
      version: 1,
      readOnly: not writable,
      status: attempt.lifecycle_state,
      score: attempt.score,
      outOf: attempt.out_of,
      parts:
        Enum.map(Attempts.get_latest_part_attempts(attempt.attempt_guid), fn part ->
          %{
            id: part.part_id,
            status: part.lifecycle_state,
            attemptNumber: part.attempt_number,
            response: part.response,
            score: part.score,
            outOf: part.out_of
          }
        end)
    }
  end
end
