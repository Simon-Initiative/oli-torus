defmodule Oli.InstructorDashboard.Oracles.Grades do
  @moduledoc """
  Returns graded-page aggregate statistics and schedule metadata for the requested scope.
  """

  use Oli.Dashboard.Oracle

  require Logger

  import Ecto.Query, warn: false

  alias Oli.Dashboard.OracleContext
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Oli.Delivery.Sections.ContainedPage
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.InstructorDashboard.Oracles.Helpers
  alias Oli.Repo
  alias Oli.Resources.ResourceType

  @histogram_labels [
    "0-10",
    "10-20",
    "20-30",
    "30-40",
    "40-50",
    "50-60",
    "60-70",
    "70-80",
    "80-90",
    "90-100"
  ]

  @oracle_execute_event [:oli, :dashboard, :oracle, :execute]
  @slow_query_threshold_ms 300

  @impl true
  def key, do: :oracle_instructor_grades

  @impl true
  def version, do: 1

  @impl true
  def load(%OracleContext{} = context, _opts) do
    with {:ok, section_id, scope} <- Helpers.section_scope(context) do
      Logger.debug(
        "grades_oracle.load.start section_id=#{section_id} container_id=#{inspect(scope.container_id)}"
      )

      started_at = System.monotonic_time()
      graded_pages = graded_pages_in_scope(section_id, scope.container_id)
      page_ids = Enum.map(graded_pages, & &1.resource_id)
      scores_by_page = scores_by_page(section_id, page_ids)
      schedule_by_page = schedule_by_page(section_id, graded_pages)
      total_students = enrolled_learner_count(section_id)

      grades =
        Enum.map(graded_pages, fn section_resource ->
          page_id = section_resource.resource_id
          page_scores = Map.get(scores_by_page, page_id, [])
          stats = stats(page_scores)
          schedule = Map.get(schedule_by_page, page_id, section_resource)
          completed_count = length(page_scores)

          %{
            page_id: page_id,
            section_resource_id: section_resource.id,
            title: section_resource.title,
            minimum: stats.minimum,
            median: stats.median,
            mean: stats.mean,
            maximum: stats.maximum,
            standard_deviation: stats.standard_deviation,
            histogram: histogram(page_scores),
            available_at: schedule.start_date,
            due_at: schedule.end_date,
            completed_count: completed_count,
            total_students: total_students
          }
        end)

      payload = %{grades: grades}
      duration_ms = duration_ms_since(started_at)
      row_count = Enum.count(grades)
      payload_size = payload_size(payload)

      emit_execute_telemetry(
        :load,
        section_id,
        scope.container_id,
        duration_ms,
        row_count,
        payload_size
      )

      log_oracle_outcome(:load, section_id, scope.container_id, duration_ms, row_count)

      {:ok, payload}
    else
      {:error, reason} = error ->
        emit_execute_error(:load, nil, nil, reason)
        Logger.error("grades_oracle.load.failed reason=#{inspect(reason)}")
        error
    end
  end

  @spec students_without_attempt_emails(pos_integer(), pos_integer()) ::
          {:ok, [map()]} | {:error, term()}
  def students_without_attempt_emails(section_id, resource_id) do
    Logger.debug(
      "grades_oracle.students_without_attempt_emails.start section_id=#{section_id} resource_id=#{resource_id}"
    )

    started_at = System.monotonic_time()
    learner_role_id = Helpers.learner_role_id()

    try do
      students =
        from(e in Enrollment,
          join: ecr in assoc(e, :context_roles),
          join: u in assoc(e, :user),
          left_join: ra in ResourceAccess,
          on:
            ra.section_id == e.section_id and
              ra.user_id == e.user_id and
              ra.resource_id == ^resource_id and
              not is_nil(ra.score) and
              not is_nil(ra.out_of) and
              ra.out_of > 0.0,
          where:
            e.section_id == ^section_id and e.status == :enrolled and ecr.id == ^learner_role_id and
              is_nil(ra.id),
          order_by: [asc: u.family_name, asc: u.given_name, asc: u.email, asc: u.id],
          distinct: u.id,
          select: %{
            id: u.id,
            display_name:
              fragment(
                "coalesce(nullif(trim(concat(coalesce(?, ''), ' ', coalesce(?, ''))), ''), ?, concat('Student ', ?::text))",
                u.given_name,
                u.family_name,
                u.email,
                u.id
              ),
            email: u.email
          }
        )
        |> Repo.all()

      duration_ms = duration_ms_since(started_at)
      row_count = Enum.count(students)
      payload_size = payload_size(students)

      emit_execute_telemetry(
        :students_without_attempt_emails,
        section_id,
        nil,
        duration_ms,
        row_count,
        payload_size
      )

      log_oracle_outcome(
        :students_without_attempt_emails,
        section_id,
        resource_id,
        duration_ms,
        row_count
      )

      {:ok, students}
    rescue
      error ->
        emit_execute_error(:students_without_attempt_emails, section_id, nil, error)

        Logger.error(
          "grades_oracle.students_without_attempt_emails.failed section_id=#{section_id} resource_id=#{resource_id} reason=#{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp graded_pages_in_scope(section_id, nil), do: graded_pages_query(section_id)

  defp graded_pages_in_scope(section_id, container_id) do
    page_type_id = ResourceType.id_for_page()

    from(cp in ContainedPage,
      join: sr in SectionResource,
      on: sr.resource_id == cp.page_id and sr.section_id == cp.section_id,
      where:
        cp.section_id == ^section_id and cp.container_id == ^container_id and
          sr.graded == true and sr.resource_type_id == ^page_type_id,
      order_by: [asc: sr.numbering_index, asc: sr.title],
      select: sr,
      distinct: true
    )
    |> Repo.all()
  end

  defp graded_pages_query(section_id) do
    page_type_id = ResourceType.id_for_page()

    from(sr in SectionResource,
      where:
        sr.section_id == ^section_id and sr.graded == true and
          sr.resource_type_id == ^page_type_id,
      order_by: [asc: sr.numbering_index, asc: sr.title],
      select: sr
    )
    |> Repo.all()
  end

  defp schedule_by_page(_section_id, []), do: %{}

  defp schedule_by_page(section_id, graded_pages) do
    page_ids = Enum.map(graded_pages, & &1.resource_id)

    (SectionResourceDepot.get_resources_by_ids(section_id, page_ids) ++ graded_pages)
    |> Enum.uniq_by(& &1.resource_id)
    |> Enum.into(%{}, fn section_resource -> {section_resource.resource_id, section_resource} end)
  end

  defp scores_by_page(_section_id, []), do: %{}

  defp scores_by_page(section_id, page_ids) do
    learner_role_id = Helpers.learner_role_id()

    from(ra in ResourceAccess,
      join: e in Enrollment,
      on: e.section_id == ra.section_id and e.user_id == ra.user_id and e.status == :enrolled,
      join: ecr in assoc(e, :context_roles),
      where:
        ra.section_id == ^section_id and
          ra.resource_id in ^page_ids and
          ecr.id == ^learner_role_id and
          not is_nil(ra.score) and
          not is_nil(ra.out_of) and
          ra.out_of > 0.0,
      select: {ra.resource_id, fragment("(? / ?) * 100.0", ra.score, ra.out_of)}
    )
    |> Repo.all()
    |> Enum.group_by(fn {page_id, _} -> page_id end, fn {_, pct} -> pct end)
  end

  defp enrolled_learner_count(section_id) do
    learner_role_id = Helpers.learner_role_id()

    from(e in Enrollment,
      join: ecr in assoc(e, :context_roles),
      where: e.section_id == ^section_id and e.status == :enrolled and ecr.id == ^learner_role_id,
      select: count(e.id, :distinct)
    )
    |> Repo.one()
  end

  defp histogram(scores) do
    Enum.reduce(scores, empty_histogram(), fn score, acc ->
      bucket = histogram_bucket(score)
      Map.update!(acc, bucket, &(&1 + 1))
    end)
  end

  defp histogram_bucket(score) when score >= 100.0, do: "90-100"
  defp histogram_bucket(score) when score <= 0.0, do: "0-10"

  defp histogram_bucket(score) do
    case trunc(score / 10.0) do
      0 -> "0-10"
      1 -> "10-20"
      2 -> "20-30"
      3 -> "30-40"
      4 -> "40-50"
      5 -> "50-60"
      6 -> "60-70"
      7 -> "70-80"
      8 -> "80-90"
      _ -> "90-100"
    end
  end

  defp empty_histogram do
    Enum.into(@histogram_labels, %{}, fn label -> {label, 0} end)
  end

  defp stats([]) do
    %{
      minimum: nil,
      median: nil,
      mean: nil,
      maximum: nil,
      standard_deviation: nil
    }
  end

  defp stats(scores) do
    sorted = Enum.sort(scores)
    count = Enum.count(sorted)
    mean = Enum.sum(sorted) / count

    variance =
      sorted
      |> Enum.reduce(0.0, fn score, acc -> acc + :math.pow(score - mean, 2) end)
      |> Kernel./(count)

    %{
      minimum: List.first(sorted),
      median: median(sorted),
      mean: mean,
      maximum: List.last(sorted),
      standard_deviation: :math.sqrt(variance)
    }
  end

  defp median([score]), do: score

  defp median(sorted_scores) do
    count = Enum.count(sorted_scores)
    middle_index = div(count, 2)

    case Integer.mod(count, 2) do
      0 ->
        left = Enum.at(sorted_scores, middle_index - 1)
        right = Enum.at(sorted_scores, middle_index)
        (left + right) / 2.0

      _ ->
        Enum.at(sorted_scores, middle_index)
    end
  end

  defp emit_execute_telemetry(
         action,
         section_id,
         container_id,
         duration_ms,
         row_count,
         payload_size
       ) do
    :telemetry.execute(
      @oracle_execute_event,
      %{duration_ms: duration_ms, row_count: row_count, payload_size: payload_size},
      %{
        oracle_key: key(),
        action: action,
        section_id: section_id,
        container_id: container_id,
        outcome: :ok
      }
    )
  end

  defp emit_execute_error(action, section_id, container_id, reason) do
    :telemetry.execute(
      @oracle_execute_event,
      %{duration_ms: 0, row_count: 0, payload_size: 0},
      %{
        oracle_key: key(),
        action: action,
        section_id: section_id,
        container_id: container_id,
        outcome: :error,
        reason: inspect(reason)
      }
    )
  end

  defp log_oracle_outcome(action, section_id, scope_id, duration_ms, row_count) do
    case duration_ms > @slow_query_threshold_ms do
      true ->
        Logger.warning(
          "grades_oracle.#{action}.slow section_id=#{section_id} scope_id=#{inspect(scope_id)} duration_ms=#{duration_ms} row_count=#{row_count}"
        )

      false ->
        Logger.info(
          "grades_oracle.#{action}.completed section_id=#{section_id} scope_id=#{inspect(scope_id)} duration_ms=#{duration_ms} row_count=#{row_count}"
        )
    end
  end

  defp duration_ms_since(started_at) do
    System.convert_time_unit(System.monotonic_time() - started_at, :native, :millisecond)
  end

  defp payload_size(payload) do
    payload
    |> :erlang.term_to_binary()
    |> byte_size()
  end
end
