defmodule Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector do
  @moduledoc """
  Non-UI projector for the Student Support tile.
  """

  @bucket_order [:struggling, :on_track, :excelling, :not_enough_information]
  @bucket_labels %{
    struggling: "Struggling",
    on_track: "On Track",
    excelling: "Excelling",
    not_enough_information: "Not enough information"
  }
  @default_rules %{
    struggling: %{any: [{:progress, :lt, 40}, {:proficiency, :lt, 40}], all: []},
    excelling: %{any: [], all: [{:progress, :gte, 60}, {:proficiency, :gte, 80}]},
    on_track: %{any: [], all: [{:progress, :gte, 40}, {:proficiency, :gte, 40}]}
  }

  @type progress_row :: %{
          required(:student_id) => pos_integer(),
          required(:progress_pct) => number() | nil,
          required(:proficiency_pct) => number() | nil
        }
  @type student_info_row :: %{
          required(:student_id) => pos_integer(),
          required(:email) => String.t() | nil,
          required(:given_name) => String.t() | nil,
          required(:family_name) => String.t() | nil,
          optional(:picture) => String.t() | nil,
          required(:last_interaction_at) => DateTime.t() | NaiveDateTime.t() | nil
        }

  @spec build([progress_row()], [student_info_row()], keyword()) :: map()
  def build(progress_rows, student_info_rows, opts \\ []) do
    inactivity_days = Keyword.get(opts, :inactivity_days, 7)
    now = Keyword.get(opts, :now, DateTime.utc_now())
    rules = Keyword.get(opts, :rules, @default_rules)
    progress_by_student = Map.new(progress_rows, &{&1.student_id, &1})

    {bucket_map, totals, has_activity_data?} =
      Enum.reduce(student_info_rows, {empty_bucket_map(), empty_totals(), false}, fn student_info,
                                                                                     {buckets,
                                                                                      totals,
                                                                                      has_activity?} ->
        progress_row = Map.get(progress_by_student, student_info.student_id, %{})
        student_row = build_student_row(student_info, progress_row, inactivity_days, now)
        bucket_id = categorize(student_row, rules)
        activity_status = student_row.activity_status

        buckets =
          Map.update!(buckets, bucket_id, fn bucket ->
            %{
              bucket
              | count: bucket.count + 1,
                active_count:
                  bucket.active_count + if(activity_status == :active, do: 1, else: 0),
                inactive_count:
                  bucket.inactive_count + if(activity_status == :inactive, do: 1, else: 0),
                students: [student_row | bucket.students]
            }
          end)

        totals =
          totals
          |> Map.update!(:total_students, &(&1 + 1))
          |> Map.update!(:active_students, &(&1 + if(activity_status == :active, do: 1, else: 0)))
          |> Map.update!(
            :inactive_students,
            &(&1 + if(activity_status == :inactive, do: 1, else: 0))
          )

        has_activity? =
          has_activity? or activity_data?(student_row.progress_pct, student_row.proficiency_pct)

        {buckets, totals, has_activity?}
      end)

    buckets =
      @bucket_order
      |> Enum.map(fn bucket_id ->
        bucket = Map.fetch!(bucket_map, bucket_id)

        %{
          id: bucket_id |> Atom.to_string(),
          label: Map.fetch!(@bucket_labels, bucket_id),
          count: bucket.count,
          pct: percent(bucket.count, totals.total_students),
          active_count: bucket.active_count,
          inactive_count: bucket.inactive_count,
          students: sort_students(bucket.students)
        }
      end)

    %{
      buckets: buckets,
      totals: totals,
      default_bucket_id: default_bucket_id(buckets),
      has_activity_data?: has_activity_data?,
      bucket_priority: Enum.map(@bucket_order, &Atom.to_string/1)
    }
  end

  defp empty_bucket_map do
    Enum.into(@bucket_order, %{}, fn bucket_id ->
      {bucket_id, %{count: 0, active_count: 0, inactive_count: 0, students: []}}
    end)
  end

  defp empty_totals do
    %{total_students: 0, active_students: 0, inactive_students: 0}
  end

  defp build_student_row(student_info, progress_row, inactivity_days, now) do
    progress_pct = normalize_progress_pct(Map.get(progress_row, :progress_pct))
    proficiency_pct = normalize_proficiency_pct(Map.get(progress_row, :proficiency_pct))
    last_interaction_at = normalize_datetime(Map.get(student_info, :last_interaction_at))

    %{
      id: student_info.student_id,
      student_id: student_info.student_id,
      display_name: display_name(student_info),
      full_name: display_name(student_info),
      email: Map.get(student_info, :email),
      picture: Map.get(student_info, :picture),
      progress_pct: progress_pct,
      proficiency_pct: proficiency_pct,
      activity_status: activity_status(last_interaction_at, inactivity_days, now),
      last_interaction_at: last_interaction_at,
      searchable_text: searchable_text(student_info)
    }
  end

  defp display_name(student_info) do
    [Map.get(student_info, :given_name), Map.get(student_info, :family_name)]
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> case do
      [] -> Map.get(student_info, :email) || "Student #{student_info.student_id}"
      names -> Enum.join(names, " ")
    end
  end

  defp searchable_text(student_info) do
    student_info
    |> display_name()
    |> Kernel.<>(Map.get(student_info, :email, "") || "")
    |> String.downcase()
  end

  defp normalize_progress_pct(nil), do: nil
  defp normalize_progress_pct(value) when is_integer(value), do: value * 1.0
  defp normalize_progress_pct(value) when is_float(value), do: Float.round(value, 1)

  # Progress already arrives in 0..100, while proficiency currently arrives as 0..1.
  # Normalize both onto the same scale before bucket classification.
  defp normalize_proficiency_pct(nil), do: nil
  defp normalize_proficiency_pct(value) when is_integer(value) and value <= 1, do: value * 100.0
  defp normalize_proficiency_pct(value) when is_integer(value), do: value * 1.0

  defp normalize_proficiency_pct(value) when is_float(value) and value <= 1.0,
    do: Float.round(value * 100.0, 1)

  defp normalize_proficiency_pct(value) when is_float(value), do: Float.round(value, 1)

  defp normalize_datetime(%DateTime{} = value), do: value

  defp normalize_datetime(%NaiveDateTime{} = value) do
    DateTime.from_naive!(value, "Etc/UTC")
  end

  defp normalize_datetime(_), do: nil

  defp activity_status(nil, _inactivity_days, _now), do: :inactive

  defp activity_status(%DateTime{} = last_interaction_at, inactivity_days, %DateTime{} = now) do
    inactivity_seconds = inactivity_days * 24 * 60 * 60

    if DateTime.diff(now, last_interaction_at, :second) >= inactivity_seconds do
      :inactive
    else
      :active
    end
  end

  defp activity_data?(progress_pct, proficiency_pct) do
    progress_pct not in [nil, 0, 0.0] or not is_nil(proficiency_pct)
  end

  defp sort_students(students) do
    Enum.sort_by(students, fn student ->
      {student.activity_status != :inactive, student.searchable_text}
    end)
  end

  defp default_bucket_id(buckets) do
    buckets
    |> Enum.find(&(Map.get(&1, :count, 0) > 0))
    |> case do
      nil -> nil
      bucket -> bucket.id
    end
  end

  defp percent(_count, 0), do: 0.0
  defp percent(count, total), do: Float.round(count / total, 4)

  defp categorize(%{progress_pct: nil}, _rules), do: :not_enough_information
  defp categorize(%{proficiency_pct: nil}, _rules), do: :not_enough_information

  defp categorize(metrics, rules) do
    cond do
      matches_rule?(rules.excelling, metrics) -> :excelling
      matches_rule?(rules.struggling, metrics) -> :struggling
      matches_rule?(rules.on_track, metrics) -> :on_track
      true -> :on_track
    end
  end

  defp matches_rule?(%{any: any_rules, all: all_rules}, metrics) do
    any_ok? = any_rules == [] or Enum.any?(any_rules, &matches_predicate?(&1, metrics))
    all_ok? = Enum.all?(all_rules, &matches_predicate?(&1, metrics))
    any_ok? and all_ok?
  end

  defp matches_predicate?({field, op, value}, metrics)
       when field in [:progress, :proficiency] do
    actual = Map.get(metrics, metric_field(field))
    compare(actual, op, value)
  end

  defp metric_field(:progress), do: :progress_pct
  defp metric_field(:proficiency), do: :proficiency_pct

  defp compare(nil, _op, _value), do: false
  defp compare(actual, :lt, value), do: actual < value
  defp compare(actual, :lte, value), do: actual <= value
  defp compare(actual, :gt, value), do: actual > value
  defp compare(actual, :gte, value), do: actual >= value
end
