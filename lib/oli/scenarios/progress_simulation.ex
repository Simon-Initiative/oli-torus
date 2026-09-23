defmodule Oli.Scenarios.ProgressSimulation do
  @moduledoc """
  Runs bounded, deterministic, profile-driven learner journeys through a delivered course.

  The simulator uses real delivery attempt and evaluation lifecycles. Profile probabilities
  choose learner behavior; they never write scores directly.
  """

  import Ecto.Query, warn: false

  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Accounts.User
  alias Oli.Activities
  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, StudentInput}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.{ContainedPage, Enrollment, EnrollmentContextRole, Section}
  alias Oli.Delivery.Settings
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias Oli.Scenarios.LearnerActions
  alias Oli.Scenarios.LearnerSession

  alias Oli.Scenarios.ProgressSimulation.{
    Pacing,
    Policy,
    Profiles,
    Responses
  }

  @max_warnings 100
  @max_failure_reasons 50
  @max_learners 100
  @empty_counts %{
    pages_visited: 0,
    practice_submissions: 0,
    assessment_submissions: 0,
    activity_resets: 0,
    part_resets: 0,
    hints_requested: 0,
    retry_limits_reached: 0
  }

  @type result :: map()

  @doc "Runs the course simulation for selected enrolled learners."
  @spec run(Sections.Section.t(), nil | [Oli.Accounts.User.t()], map()) ::
          {:ok, result()} | {:error, term(), result()}
  def run(section, selected_users, opts) do
    pages = Sections.fetch_all_pages(section.slug, nil, :numbering_index)
    registrations = activity_registrations()

    with {:ok, activities} <- load_activities(section, pages),
         {:ok, users} <- select_users(selected_users, section),
         {:ok, assignments} <- assign_profiles(users, opts),
         :ok <- validate_learner_count(assignments),
         :ok <- ensure_contained_pages(section, pages),
         {fresh, skipped} <- partition_existing_history(section, assignments) do
      course = %{section: section, pages: pages, registrations: registrations}
      execute_simulation(section, pages, activities, fresh, skipped, opts, course)
    else
      {:error, reason} -> {:error, reason, empty_summary(section, pages, opts)}
    end
  end

  defp execute_simulation(section, pages, activities, assignments, skipped, opts, shared_data) do
    opts = Map.put(opts, :shared_data, shared_data)

    summary =
      assignments
      |> run_assignments(shared_data, opts, empty_summary(section, pages, opts, activities))
      |> finalize_summary(length(assignments), skipped)

    case summary.failed do
      0 -> {:ok, summary}
      failed -> {:error, {:learner_failures, failed, summary.failure_reasons}, summary}
    end
  end

  defp ensure_contained_pages(section, pages) do
    expected_page_ids = MapSet.new(pages, & &1.resource_id)

    contained_page_ids =
      ContainedPage
      |> where([page], page.section_id == ^section.id and is_nil(page.container_id))
      |> select([page], page.page_id)
      |> Repo.all()
      |> MapSet.new()

    case contained_page_ids == expected_page_ids do
      true ->
        :ok

      false ->
        Sections.rebuild_contained_pages(section)
        :ok
    end
  rescue
    exception -> {:error, {:contained_pages_rebuild_failed, Exception.message(exception)}}
  end

  @doc "Returns the native activity slugs supported by course simulation."
  @spec supported_activity_types() :: [String.t()]
  def supported_activity_types, do: Responses.supported_activity_types()

  @doc false
  def response_for_part(slug, part_id, activity, opts) do
    probability = Map.fetch!(opts, :correctness)
    seed_key = {opts.seed, Map.get(opts, :user_id), stable_activity_identity(activity), part_id}

    case Responses.for_part(slug, part_id, activity, probability, seed_key) do
      {:ok, input} -> input
      {:unsupported, _reason} -> nil
    end
  end

  @doc false
  def select_response(responses, probability, seed_key) do
    activity = %{
      resource_id: 1,
      content: %{
        "activityType" => "oli_short_answer",
        "authoring" => %{"parts" => [%{"id" => "1", "responses" => responses}]}
      }
    }

    case Responses.for_part("oli_short_answer", "1", activity, probability, seed_key) do
      {:ok, %StudentInput{input: input}} -> input
      _ -> nil
    end
  end

  defp run_assignments([], _shared_data, _opts, summary), do: summary

  defp run_assignments(assignments, shared_data, opts, summary) do
    stream_options = [ordered: false, timeout: :infinity, on_timeout: :kill_task]

    stream_options =
      case opts.timing do
        :paced -> Keyword.put(stream_options, :max_concurrency, length(assignments))
        :fast -> stream_options
      end

    Task.async_stream(assignments, &simulate_learner(&1, shared_data, opts), stream_options)
    |> Enum.reduce(summary, fn
      {:ok, outcome}, summary -> reduce_outcome(summary, outcome)
      {:exit, reason}, summary -> reduce_outcome(summary, failed_outcome("unknown", reason))
    end)
  end

  defp simulate_learner(%{user: user, profile: profile}, shared_data, opts) do
    identity = stable_user_identity(user)
    traits = Policy.learner_traits(profile, opts.seed, identity)
    Process.put(:progress_pace_tendency, traits.pace_tendency)
    base = learner_outcome(identity, profile.name)
    Process.put(:progress_outcome, base)

    timing = Profiles.timing(profile.name)

    with :ok <- paced_wait(opts, timing.start_delay, {identity, :start}),
         section <- shared_data.section,
         total_pages <- length(shared_data.pages),
         registrations <- shared_data.registrations,
         :ok <- initialize_learner_session(profile, section, identity, opts),
         pages_to_visit <- Policy.pages_to_visit(total_pages, traits.course_reach),
         {:ok, outcome} <-
           simulate_pages(
             pages_to_visit,
             total_pages,
             shared_data,
             section,
             user,
             profile,
             traits,
             registrations,
             opts,
             base
           ) do
      outcome
    else
      {:error, reason} ->
        current_outcome(base)
        |> Map.merge(%{status: :failed, reason: failure_category(reason)})
    end
  rescue
    exception ->
      identity = stable_user_identity(user)

      learner_outcome(identity, profile.name)
      |> current_outcome()
      |> Map.merge(%{status: :failed, reason: failure_category(exception), profile: profile.name})
  end

  defp simulate_pages(
         pages_to_visit,
         total_pages,
         shared_data,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome
       ) do
    shared_data.pages
    |> Enum.take(pages_to_visit)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, outcome}, fn {page, index}, {:ok, acc} ->
      with :ok <- page_boundary_wait(index, profile, user, opts),
           {:ok, updated} <-
             simulate_page(
               page,
               section,
               user,
               profile,
               traits,
               registrations,
               opts,
               acc,
               index
             ) do
        {:cont, {:ok, updated}}
      else
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, final} ->
        status =
          cond do
            pages_to_visit > 0 and final.blocked_pages == pages_to_visit -> :blocked
            final.blocked_pages > 0 -> :partial
            pages_to_visit == total_pages -> :course_complete
            true -> :partial
          end

        {:ok, %{final | status: status}}

      other ->
        other
    end
  end

  defp simulate_page(
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index
       ) do
    case page.graded do
      true ->
        simulate_graded_page_attempt(
          page,
          section,
          user,
          profile,
          traits,
          registrations,
          opts,
          outcome,
          page_index,
          1
        )

      false ->
        simulate_practice_page(
          page,
          section,
          user,
          profile,
          traits,
          registrations,
          opts,
          outcome,
          page_index
        )
    end
  end

  defp simulate_practice_page(
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index
       ) do
    identity = stable_user_identity(user)
    begin_page_timing()
    session_id = current_session_id()

    case LearnerActions.visit(section, page, user, session_id) do
      {:ok, %{hierarchy: hierarchy} = visit} ->
        record_session_page()

        with :ok <- validate_automatic_hierarchy(hierarchy, page),
             outcome <- increment(outcome, :pages_visited),
             {:ok, outcome} <-
               simulate_page_activities(
                 page,
                 visit,
                 hierarchy,
                 section,
                 user,
                 profile,
                 traits,
                 registrations,
                 opts,
                 outcome,
                 page_index,
                 1
               ) do
          complete_page_residence(outcome, profile, identity, page_index, opts)
        else
          {:unsupported_grading, reason} ->
            {:ok,
             outcome
             |> Map.update!(:blocked_pages, &(&1 + 1))
             |> add_warning({:blocked_page, reason})}

          other ->
            other
        end

      {:blocked, reason} ->
        {:ok,
         outcome
         |> Map.update!(:blocked_pages, &(&1 + 1))
         |> add_warning({:blocked_page, reason})}
    end
  end

  defp complete_page_residence(outcome, profile, identity, page_index, opts) do
    case page_residence_wait(profile, identity, page_index, opts) do
      :ok -> {:ok, outcome}
      other -> other
    end
  end

  defp simulate_graded_page_attempt(
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index,
         attempt_number
       ) do
    effective_settings = Settings.get_combined_settings(page, section.id, user.id)

    cond do
      not effective_settings.batch_scoring ->
        {:ok,
         outcome
         |> Map.update!(:blocked_pages, &(&1 + 1))
         |> add_warning({:blocked_page, :unsupported_score_as_you_go})}

      not assessment_attempt_available?(attempt_number, effective_settings.max_attempts) ->
        {:ok, increment(outcome, :retry_limits_reached)}

      true ->
        do_simulate_graded_page_attempt(
          page,
          section,
          user,
          profile,
          traits,
          registrations,
          opts,
          outcome,
          page_index,
          attempt_number,
          effective_settings
        )
    end
  end

  defp assessment_attempt_available?(_attempt_number, 0), do: true
  defp assessment_attempt_available?(attempt_number, maximum), do: attempt_number <= maximum

  defp do_simulate_graded_page_attempt(
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index,
         attempt_number,
         effective_settings
       ) do
    identity = stable_user_identity(user)
    begin_page_timing()
    session_id = current_session_id()

    with {:ok, %{hierarchy: hierarchy, resource_attempt: %{} = resource_attempt} = visit} <-
           LearnerActions.visit(section, page, user, session_id),
         :ok <- maybe_record_assessment_page(attempt_number),
         :ok <- validate_automatic_hierarchy(hierarchy, page),
         outcome <- if(attempt_number == 1, do: increment(outcome, :pages_visited), else: outcome),
         {:ok, outcome} <-
           simulate_page_activities(
             page,
             visit,
             hierarchy,
             section,
             user,
             profile,
             traits,
             registrations,
             opts,
             outcome,
             page_index,
             attempt_number
           ),
         {:ok, fresh_resource} when not is_nil(fresh_resource) <-
           {:ok, Core.get_resource_attempt_by(attempt_guid: resource_attempt.attempt_guid)} do
      complete_assessment_residence(
        outcome,
        page,
        section,
        user,
        profile,
        traits,
        registrations,
        opts,
        identity,
        page_index,
        attempt_number,
        effective_settings
      )
    else
      {:blocked, reason} when attempt_number > 1 ->
        case retry_exhausted_error?(reason) do
          true ->
            {:ok, increment(outcome, :retry_limits_reached)}

          false ->
            {:ok,
             outcome
             |> Map.update!(:blocked_pages, &(&1 + 1))
             |> add_warning({:blocked_page, reason})}
        end

      {:blocked, reason} ->
        {:ok,
         outcome
         |> Map.update!(:blocked_pages, &(&1 + 1))
         |> add_warning({:blocked_page, reason})}

      {:error, _reason} = error ->
        error

      {:unsupported_grading, reason} ->
        {:ok,
         outcome
         |> Map.update!(:blocked_pages, &(&1 + 1))
         |> add_warning({:blocked_page, reason})}

      nil ->
        {:error, :missing_finalized_resource_attempt}
    end
  end

  defp complete_assessment_residence(
         outcome,
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         identity,
         page_index,
         attempt_number,
         effective_settings
       ) do
    with :ok <- page_residence_wait(profile, identity, page_index, opts) do
      retry? = attempt_number < profile.assessment_attempts

      case retry? do
        false ->
          {:ok, outcome}

        true ->
          case assessment_attempt_available?(
                 attempt_number + 1,
                 effective_settings.max_attempts
               ) do
            false ->
              {:ok, increment(outcome, :retry_limits_reached)}

            true ->
              with :ok <-
                     session_wait(opts, Profiles.timing(profile.name).retry_delay, {
                       identity,
                       stable_page_identity(page, page_index),
                       attempt_number,
                       :assessment_retry
                     }) do
                do_simulate_graded_page_attempt(
                  page,
                  section,
                  user,
                  profile,
                  traits,
                  registrations,
                  opts,
                  outcome,
                  page_index,
                  attempt_number + 1,
                  effective_settings
                )
              end
          end
      end
    end
  end

  defp simulate_page_activities(
         page,
         visit,
         hierarchy,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index,
         attempt_number
       ) do
    result =
      hierarchy
      |> LearnerActions.activities(page.activity_refs)
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, outcome}, fn {activity, activity_index}, {:ok, acc} ->
        participate? =
          page.graded or
            Policy.take?(
              traits.participation,
              opts.seed,
              stable_user_identity(user),
              {:participation, stable_page_identity(page, page_index), activity_index}
            )

        case participate? do
          false ->
            {:cont, {:ok, acc}}

          true ->
            case attempt_activity(
                   activity,
                   page,
                   section,
                   user,
                   profile,
                   traits,
                   registrations,
                   opts,
                   acc,
                   page_index,
                   activity_index,
                   attempt_number
                 ) do
              {:ok, updated} -> {:cont, {:ok, updated}}
              {:unsupported, reason, updated} -> {:cont, {:ok, add_warning(updated, reason)}}
              {:error, _reason} = error -> {:halt, error}
            end
        end
      end)

    case {result, page.graded, visit.resource_attempt} do
      {{:ok, updated}, true, %{} = resource_attempt} ->
        session_id = current_session_id()

        case LearnerActions.finalize(section, resource_attempt, session_id) do
          {:ok, _summary} -> {:ok, increment(updated, :assessment_submissions)}
          {:error, reason} -> {:error, {:finalize_failed, reason}}
        end

      {{:ok, _updated}, true, nil} ->
        {:error, :missing_resource_attempt}

      {other, _graded, _attempt} ->
        other
    end
  end

  defp attempt_activity(
         activity,
         page,
         section,
         user,
         profile,
         traits,
         registrations,
         opts,
         outcome,
         page_index,
         activity_index,
         attempt_number
       ) do
    activity_attempt = activity.activity_attempt
    slug = activity_slug(activity_attempt, registrations)
    correctness = Policy.correctness(traits, profile, attempt_number)
    identity = stable_user_identity(user)

    with :ok <-
           session_wait(opts, Profiles.timing(profile.name).answer_time, {
             identity,
             page_index,
             activity_index,
             attempt_number,
             :answer
           }),
         {:ok, part_inputs} <-
           build_part_inputs(activity, slug, correctness, {
             opts.seed,
             identity,
             stable_page_identity(page, page_index),
             activity_index,
             attempt_number
           }),
         {:ok, _result} <-
           submit_or_save(
             page,
             section,
             activity_attempt,
             part_inputs,
             current_session_id(),
             opts
           ),
         {:ok, fresh} when not is_nil(fresh) <-
           {:ok, Core.get_activity_attempt_by(attempt_guid: activity_attempt.attempt_guid)} do
      submitted_outcome =
        outcome
        |> increment(
          if(page.graded, do: :assessment_activity_submissions, else: :practice_submissions)
        )

      outcome = submitted_outcome

      case retry?(page, profile, attempt_number, score_ratio(fresh)) do
        false ->
          {:ok, outcome}

        true ->
          max_attempts =
            if page.graded,
              do: profile.assessment_attempts,
              else: profile.practice_attempts

          case attempt_number >= max_attempts do
            true ->
              {:ok, increment(outcome, :retry_limits_reached)}

            false ->
              with {:ok, outcome} <-
                     maybe_request_hint(fresh, opts, outcome),
                   :ok <-
                     session_wait(opts, Profiles.timing(profile.name).retry_delay, {
                       identity,
                       stable_page_identity(page, page_index),
                       activity_index,
                       attempt_number,
                       :retry
                     }),
                   {:ok, refreshed, outcome} <-
                     reset_for_retry(
                       fresh,
                       page,
                       section,
                       user,
                       opts,
                       current_session_id(),
                       outcome
                     ),
                   next when not is_nil(next) <-
                     find_activity(refreshed.hierarchy, fresh.resource_id) do
                attempt_activity(
                  next,
                  page,
                  section,
                  user,
                  profile,
                  traits,
                  registrations,
                  opts,
                  outcome,
                  page_index,
                  activity_index,
                  attempt_number + 1
                )
              else
                nil ->
                  {:error, :missing_reset_attempt}

                {:error, reason} = error ->
                  case retry_exhausted_error?(reason) do
                    true -> {:ok, increment(outcome, :retry_limits_reached)}
                    false -> error
                  end
              end
          end
      end
    else
      {:unsupported, reason} -> {:unsupported, reason, outcome}
      {:error, _reason} = error -> error
      nil -> {:error, :missing_activity_attempt}
    end
  end

  defp retry_exhausted_error?(:no_more_attempts), do: true
  defp retry_exhausted_error?({:no_more_attempts}), do: true
  defp retry_exhausted_error?({_, reason}), do: retry_exhausted_error?(reason)
  defp retry_exhausted_error?(_reason), do: false

  defp build_part_inputs(activity, slug, correctness, seed_key) do
    activity.part_attempts
    |> current_part_attempts()
    |> Enum.filter(&(Map.get(&1, :lifecycle_state) == :active))
    |> Enum.reduce_while({:ok, []}, fn part_attempt, {:ok, inputs} ->
      case Responses.for_part(
             slug,
             part_attempt.part_id,
             activity.activity_attempt,
             correctness,
             {seed_key, part_attempt.part_id}
           ) do
        {:ok, input} ->
          {:cont,
           {:ok,
            [
              %{
                part_id: part_attempt.part_id,
                attempt_guid: part_attempt.attempt_guid,
                input: input
              }
              | inputs
            ]}}

        {:unsupported, reason} ->
          {:halt, {:unsupported, reason}}
      end
    end)
    |> case do
      {:ok, []} -> {:unsupported, {:missing_parts, slug}}
      {:ok, inputs} -> {:ok, Enum.reverse(inputs)}
      other -> other
    end
  end

  defp validate_automatic_hierarchy(hierarchy, page) do
    manual? =
      hierarchy
      |> LearnerActions.activities(page.activity_refs)
      |> Enum.any?(fn activity ->
        Enum.any?(activity.part_attempts, &(Map.get(&1, :grading_approach) == :manual))
      end)

    case manual? do
      true -> {:unsupported_grading, :manual_grading_not_supported}
      false -> :ok
    end
  end

  defp submit_or_save(
         %{graded: true},
         _section,
         _activity_attempt,
         part_inputs,
         _session_id,
         _opts
       ) do
    LearnerActions.save_activity(part_inputs)
  end

  defp submit_or_save(
         %{graded: false},
         section,
         activity_attempt,
         part_inputs,
         session_id,
         _opts
       ) do
    case activity_attempt |> activity_content() |> Map.get("submitPerPart", false) do
      false ->
        LearnerActions.submit_activity(section, activity_attempt, part_inputs, session_id)

      true ->
        Enum.reduce_while(part_inputs, {:ok, []}, fn part_input, {:ok, results} ->
          case LearnerActions.submit_part(section, activity_attempt, part_input, session_id) do
            {:ok, result} -> {:cont, {:ok, [result | results]}}
            {:error, _reason} = error -> {:halt, error}
          end
        end)
    end
  end

  defp retry?(page, profile, attempt_number, score) do
    not page.graded and score < 1.0 and attempt_number < profile.practice_attempts
  end

  defp maybe_request_hint(activity_attempt, _opts, outcome) do
    failed_part =
      activity_attempt.part_attempts
      |> current_part_attempts()
      |> Enum.find(&(score_ratio(&1) < 1.0))

    request? = not is_nil(failed_part)

    case request? do
      true ->
        case LearnerActions.request_hint(activity_attempt, failed_part) do
          {:ok, _hint} ->
            {:ok, increment(outcome, :hints_requested)}

          {:error, reason} = error ->
            case no_more_hints_error?(reason) do
              true -> {:ok, outcome}
              false -> error
            end
        end

      false ->
        {:ok, outcome}
    end
  end

  defp no_more_hints_error?(:no_more_hints), do: true
  defp no_more_hints_error?({:no_more_hints}), do: true
  defp no_more_hints_error?({_, reason}), do: no_more_hints_error?(reason)
  defp no_more_hints_error?(_reason), do: false

  defp reset_for_retry(activity_attempt, page, section, user, opts, session_id, outcome) do
    submit_per_part? =
      activity_attempt
      |> activity_content()
      |> Map.get("submitPerPart", false)

    reset_result =
      case submit_per_part? do
        true -> reset_failed_parts(activity_attempt, opts, session_id, outcome)
        false -> reset_whole_activity(activity_attempt, section, opts, session_id, outcome)
      end

    with {:ok, outcome} <- reset_result,
         {:ok, refreshed} <-
           LearnerActions.visit(section, page, user, session_id) do
      {:ok, refreshed, outcome}
    end
  end

  defp reset_failed_parts(activity_attempt, _opts, session_id, outcome) do
    activity_attempt.part_attempts
    |> current_part_attempts()
    |> Enum.filter(&(score_ratio(&1) < 1.0))
    |> Enum.reduce_while({:ok, outcome}, fn part_attempt, {:ok, acc} ->
      case LearnerActions.reset_part(activity_attempt, part_attempt, session_id) do
        {:ok, _part_state} -> {:cont, {:ok, increment(acc, :part_resets)}}
        {:error, reason} -> {:halt, {:error, {:part_reset_failed, reason}}}
      end
    end)
  end

  defp current_part_attempts(part_attempts) do
    part_attempts
    |> Enum.group_by(& &1.part_id)
    |> Enum.map(fn {_part_id, attempts} ->
      Enum.max_by(attempts, &{Map.get(&1, :attempt_number, 1), Map.get(&1, :id, 0)})
    end)
    |> Enum.sort_by(& &1.part_id)
  end

  defp reset_whole_activity(activity_attempt, section, _opts, session_id, outcome) do
    case LearnerActions.reset_activity(section, activity_attempt, session_id) do
      {:ok, _activity_state} -> {:ok, increment(outcome, :activity_resets)}
      {:error, reason} -> {:error, {:activity_reset_failed, reason}}
    end
  end

  defp paced_wait(opts, distribution, key) do
    duration = sample_wait_duration(opts, distribution, key)
    wait_duration(opts, duration)
  end

  defp session_wait(opts, distribution, key) do
    duration = sample_wait_duration(opts, distribution, key)

    with :ok <- wait_duration(opts, duration), do: add_page_modeled_time(duration)
  end

  defp sample_wait_duration(opts, distribution, key) do
    Policy.paced_triangular(
      distribution,
      Process.get(:progress_pace_tendency, 0.5),
      {opts.seed, key}
    )
  end

  defp wait_duration(%{timing: :paced}, duration), do: Pacing.wait(duration)
  defp wait_duration(%{timing: :fast}, modeled_duration), do: Pacing.fast_wait(modeled_duration)

  defp page_residence_wait(profile, identity, page_index, opts) do
    residence =
      Policy.paced_triangular(
        Profiles.timing(profile.name).page_time,
        Process.get(:progress_pace_tendency, 0.5),
        {opts.seed, identity, page_index, :page_time}
      )

    remaining = max(residence - Process.get(:progress_page_modeled_ms, 0), 0)

    with :ok <- wait_duration(opts, remaining), do: add_page_modeled_time(remaining)
  end

  defp page_boundary_wait(0, _profile, _user, _opts), do: :ok

  defp page_boundary_wait(index, profile, user, opts) do
    identity = stable_user_identity(user)
    session = Process.get(:progress_timing_session) || raise "timing session not initialized"
    timing = Profiles.timing(profile.name)

    cond do
      session.pages_used >= session.page_limit ->
        duration =
          sample_wait_duration(opts, timing.session_gap, {
            identity,
            session.ordinal,
            index,
            :session_gap
          })

        with :ok <- wait_duration(opts, duration),
             do: reset_timing_session(profile, identity, opts)

      Policy.take?(
        timing.break_probability,
        opts.seed,
        identity,
        {:break, index}
      ) ->
        duration =
          sample_wait_duration(opts, timing.break_duration, {identity, index, :break})

        wait_duration(opts, duration)

      true ->
        :ok
    end
  end

  defp initialize_learner_session(profile, section, identity, opts) do
    Process.put(
      :progress_datashop_session_id,
      LearnerSession.deterministic_id(opts.seed, identity, section.slug)
    )

    page_limit =
      Policy.session_page_limit(
        Profiles.timing(profile.name).session_pages,
        opts.seed,
        identity,
        0
      )

    Process.put(:progress_timing_session, %{ordinal: 0, pages_used: 0, page_limit: page_limit})

    :ok
  end

  defp current_session_id,
    do: Process.get(:progress_datashop_session_id) || raise("DataShop session not initialized")

  defp record_session_page do
    session = Process.get(:progress_timing_session) || raise "timing session not initialized"
    Process.put(:progress_timing_session, %{session | pages_used: session.pages_used + 1})
    :ok
  end

  defp maybe_record_assessment_page(1), do: record_session_page()
  defp maybe_record_assessment_page(_attempt_number), do: :ok

  defp reset_timing_session(profile, identity, opts) do
    current = Process.get(:progress_timing_session) || raise "timing session not initialized"
    ordinal = current.ordinal + 1

    page_limit =
      Policy.session_page_limit(
        Profiles.timing(profile.name).session_pages,
        opts.seed,
        identity,
        ordinal
      )

    Process.put(:progress_timing_session, %{
      ordinal: ordinal,
      pages_used: 0,
      page_limit: page_limit
    })

    :ok
  end

  defp begin_page_timing, do: Process.put(:progress_page_modeled_ms, 0)

  defp add_page_modeled_time(duration) do
    Process.put(
      :progress_page_modeled_ms,
      Process.get(:progress_page_modeled_ms, 0) + duration
    )

    :ok
  end

  defp assign_profiles(users, %{profile: profile_name}) when is_binary(profile_name) do
    with {:ok, profile} <- Profiles.resolve(profile_name) do
      {:ok, Enum.map(users, &%{user: &1, profile: profile})}
    end
  end

  defp assign_profiles(users, %{cohorts: cohorts} = opts) when is_list(cohorts) do
    with ordered <- stable_shuffle(users, opts.seed),
         {:ok, assignments, leftovers} <- assign_count_cohorts(cohorts, ordered),
         true <- leftovers == [] do
      {:ok, assignments}
    else
      false -> {:error, :invalid_or_incomplete_cohort_assignment}
      {:error, _reason} = error -> error
      _ -> {:error, :invalid_or_incomplete_cohort_assignment}
    end
  end

  defp assign_profiles(_users, _opts), do: {:error, :missing_profile_selection}

  defp assign_count_cohorts(cohorts, users) do
    cohorts
    |> Enum.filter(&Map.has_key?(&1, :count))
    |> Enum.reduce_while({:ok, [], users}, fn cohort, {:ok, acc, remaining} ->
      {selected, rest} = Enum.split(remaining, cohort.count)

      with true <- length(selected) == cohort.count,
           {:ok, profile} <- Profiles.resolve(cohort.profile) do
        additions = Enum.map(selected, &%{user: &1, profile: profile})
        {:cont, {:ok, Enum.reverse(additions, acc), rest}}
      else
        false -> {:halt, {:error, :cohort_count_exceeds_selected_population}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed, remaining} -> {:ok, Enum.reverse(reversed), remaining}
      error -> error
    end
  end

  defp stable_shuffle(users, seed) do
    Enum.sort_by(users, &Policy.sample({seed, stable_user_identity(&1), :cohort_assignment}))
  end

  defp select_users(nil, section) do
    {:ok,
     enrolled_learners(section, nil, @max_learners + 1)
     |> stable_sort()}
  end

  defp select_users(selected_users, section) do
    selected_ids = Enum.map(selected_users, & &1.id)

    enrolled_ids =
      section
      |> enrolled_learners(selected_ids, @max_learners + 1)
      |> MapSet.new(& &1.id)

    case Enum.reject(selected_users, &MapSet.member?(enrolled_ids, &1.id)) do
      [] -> {:ok, stable_sort(selected_users)}
      rejected -> {:error, {:users_not_enrolled_as_learners, length(rejected)}}
    end
  end

  defp enrolled_learners(section, selected_ids, limit) do
    learner_role_id = ContextRoles.get_role(:context_learner).id

    query =
      from(user in User,
        join: enrollment in Enrollment,
        on: enrollment.user_id == user.id,
        join: joined_section in Section,
        on: joined_section.id == enrollment.section_id,
        join: enrollment_role in EnrollmentContextRole,
        on: enrollment_role.enrollment_id == enrollment.id,
        where: joined_section.id == ^section.id,
        where: enrollment.status == :enrolled,
        where: enrollment_role.context_role_id == ^learner_role_id,
        distinct: true,
        limit: ^limit,
        select: user
      )

    query =
      case selected_ids do
        nil -> query
        ids -> where(query, [user, _enrollment, _section, _role], user.id in ^ids)
      end

    Repo.all(query)
  end

  defp stable_sort(users), do: Enum.sort_by(users, &stable_user_identity/1)

  defp validate_learner_count(assignments) do
    case length(assignments) <= @max_learners do
      true -> :ok
      false -> {:error, {:learner_limit_exceeded, length(assignments), @max_learners}}
    end
  end

  defp partition_existing_history(_section, []), do: {[], 0}

  defp partition_existing_history(section, assignments) do
    user_ids = Enum.map(assignments, & &1.user.id)

    existing_ids =
      from(access in ResourceAccess,
        where: access.section_id == ^section.id and access.user_id in ^user_ids,
        distinct: true,
        select: access.user_id
      )
      |> Repo.all()
      |> MapSet.new()

    {existing, fresh} = Enum.split_with(assignments, &MapSet.member?(existing_ids, &1.user.id))
    {fresh, length(existing)}
  end

  defp load_activities(section, pages) do
    activity_ids =
      pages
      |> Enum.flat_map(&Map.get(&1, :activity_refs, []))
      |> Enum.uniq()

    activities =
      section.slug
      |> DeliveryResolver.from_resource_id(activity_ids)
      |> Enum.reject(&is_nil/1)

    cond do
      length(activities) != length(activity_ids) ->
        {:error, {:unresolved_activity_references, length(activity_ids) - length(activities)}}

      Enum.any?(activities, &manual_grading_model?(&1.content)) ->
        {:error, {:unsupported_grading, :manual_grading_not_supported}}

      true ->
        {:ok, activities}
    end
  end

  defp manual_grading_model?(%{} = model) do
    Enum.any?(model, fn
      {key, value} when key in ["gradingApproach", :gradingApproach] ->
        value in ["manual", :manual]

      {_key, value} ->
        manual_grading_model?(value)
    end)
  end

  defp manual_grading_model?(values) when is_list(values),
    do: Enum.any?(values, &manual_grading_model?/1)

  defp manual_grading_model?(_value), do: false

  defp finalize_summary(summary, learner_count, skipped) do
    warning_entries = summary.warning_counts |> Enum.sort_by(fn {key, _count} -> inspect(key) end)

    %{
      summary
      | learners: learner_count + skipped,
        skipped_existing_history: skipped,
        warnings: warning_entries |> Enum.take(@max_warnings) |> Enum.map(&warning_entry/1),
        warnings_truncated: length(warning_entries) > @max_warnings,
        warning_counts: nil
    }
  end

  defp reduce_outcome(summary, outcome) do
    status = outcome.status

    summary
    |> Map.update!(:processed, &(&1 + if(status == :failed, do: 0, else: 1)))
    |> Map.update!(status, &(&1 + 1))
    |> merge_counts(outcome)
    |> merge_warnings(outcome.warnings)
    |> merge_failure(outcome)
    |> update_profile_totals(outcome)
  end

  defp empty_summary(section, _pages, opts, _activities \\ nil) do
    Map.merge(@empty_counts, %{
      learners: 0,
      processed: 0,
      course_complete: 0,
      partial: 0,
      blocked: 0,
      failed: 0,
      skipped_existing_history: 0,
      assessment_activity_submissions: 0,
      blocked_pages: 0,
      failure_reasons: %{},
      profiles: %{},
      warnings: [],
      warnings_truncated: false,
      warning_counts: %{},
      timing_mode: Map.get(opts, :timing, :fast),
      section: section.slug
    })
  end

  defp learner_outcome(identity, profile) do
    Map.merge(@empty_counts, %{
      identity: identity,
      profile: profile,
      status: :partial,
      reason: nil,
      assessment_activity_submissions: 0,
      blocked_pages: 0,
      warnings: %{}
    })
  end

  defp failed_outcome(identity, reason) do
    Map.merge(learner_outcome(identity, "unknown"), %{
      status: :failed,
      reason: failure_category(reason)
    })
  end

  defp increment(map, key) do
    updated = Map.update!(map, key, &(&1 + 1))
    Process.put(:progress_outcome, updated)
    updated
  end

  defp add_warning(outcome, warning) do
    updated =
      Map.update!(outcome, :warnings, fn warnings ->
        bounded_increment(warnings, warning, @max_warnings, :other)
      end)

    Process.put(:progress_outcome, updated)
    updated
  end

  defp current_outcome(fallback), do: Process.get(:progress_outcome, fallback)

  defp merge_counts(summary, outcome) do
    keys = Map.keys(@empty_counts) ++ [:assessment_activity_submissions, :blocked_pages]

    Enum.reduce(keys, summary, fn key, acc ->
      Map.update!(acc, key, &(&1 + Map.get(outcome, key, 0)))
    end)
  end

  defp merge_warnings(summary, warnings) do
    Map.update!(summary, :warning_counts, fn existing ->
      Enum.reduce(warnings, existing, fn {warning, count}, acc ->
        bounded_increment(acc, warning, @max_warnings, :other, count)
      end)
    end)
  end

  defp merge_failure(summary, %{status: :failed, reason: reason}) do
    Map.update!(summary, :failure_reasons, fn reasons ->
      bounded_increment(reasons, reason, @max_failure_reasons, "other")
    end)
  end

  defp merge_failure(summary, _outcome), do: summary

  defp update_profile_totals(summary, outcome) do
    Map.update!(summary, :profiles, fn profiles ->
      Map.update(
        profiles,
        outcome.profile,
        %{learners: 1, outcomes: %{outcome.status => 1}},
        fn current ->
          current
          |> Map.update!(:learners, &(&1 + 1))
          |> Map.update!(:outcomes, fn outcomes ->
            Map.update(outcomes, outcome.status, 1, &(&1 + 1))
          end)
        end
      )
    end)
  end

  defp bounded_increment(values, key, maximum, overflow_key, increment \\ 1) do
    cond do
      Map.has_key?(values, key) -> Map.update!(values, key, &(&1 + increment))
      map_size(values) < maximum -> Map.put(values, key, increment)
      true -> Map.update(values, overflow_key, increment, &(&1 + increment))
    end
  end

  defp warning_entry({{:activity_type, slug}, count}),
    do: %{type: :unsupported_content, activity_type: slug, count: count}

  defp warning_entry({{:activity_model, slug, part_id}, count}),
    do: %{type: :unsupported_content, activity_type: slug, part_id: part_id, count: count}

  defp warning_entry({{:response_rule, slug, part_id}, count}),
    do: %{type: :unsupported_response_rule, activity_type: slug, part_id: part_id, count: count}

  defp warning_entry({{:blocked_page, reason}, count}),
    do: %{type: :blocked_page, reason: failure_category(reason), count: count}

  defp warning_entry({reason, count}),
    do: %{type: :simulation_warning, reason: failure_category(reason), count: count}

  defp activity_slug(%{revision: %{activity_type: %{slug: slug}}}, _registrations), do: slug

  defp activity_slug(%{revision: %{activity_type_id: id}}, registrations),
    do: Map.get(registrations, id)

  defp activity_slug(_activity_attempt, _registrations), do: nil

  defp activity_content(%{transformed_model: model}) when is_map(model), do: model
  defp activity_content(%{revision: %{content: content}}), do: content

  defp find_activity(hierarchy, resource_id) do
    hierarchy
    |> LearnerActions.activities()
    |> Enum.find(&(&1.activity_attempt.resource_id == resource_id))
  end

  defp score_ratio(%{score: score, out_of: out_of})
       when is_number(score) and is_number(out_of) and out_of > 0,
       do: score / out_of

  defp score_ratio(_), do: 0.0

  defp activity_registrations,
    do: Map.new(Activities.list_activity_registrations(), &{&1.id, &1.slug})

  defp stable_user_identity(user), do: user.sub || user.email || "user:#{user.id}"

  defp stable_page_identity(page, index), do: {index, page.title || "untitled"}

  defp stable_activity_identity(%{activity_attempt: attempt}),
    do: stable_activity_identity(attempt)

  defp stable_activity_identity(%{revision: %{title: title}}) when is_binary(title), do: title
  defp stable_activity_identity(%{title: title}) when is_binary(title), do: title
  defp stable_activity_identity(_activity), do: "untitled_activity"

  defp failure_category(%{__struct__: module}), do: module |> Module.split() |> List.last()

  defp failure_category(reason) when is_atom(reason), do: Atom.to_string(reason)

  defp failure_category(reason) when is_tuple(reason) do
    case Tuple.to_list(reason) do
      [tag | _] when is_atom(tag) -> Atom.to_string(tag)
      _ -> "domain_error"
    end
  end

  defp failure_category(_reason), do: "domain_error"
end
