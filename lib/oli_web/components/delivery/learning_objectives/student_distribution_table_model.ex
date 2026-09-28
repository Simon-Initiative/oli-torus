defmodule OliWeb.Components.Delivery.LearningObjectives.StudentDistributionTableModel do
  @moduledoc """
  Column metadata and sorting for the Student Distribution group table.

  `StudentDistributionTable` renders its own `<table>` markup directly (real per-row
  striping, accessible sortable headers, and a selection checkbox column don't fit the
  generic `OliWeb.Common.SortableTable.Table` renderer well), so this module only owns the
  column list and the actual sort logic -- no `ColumnSpec`/`SortableTableModel` machinery.

  Each distribution group has its own default proficiency sort order, since the label mix
  differs by group (e.g. Excelling students are rarely labeled "Low"). The ordering applies
  whenever sorting by the `:proficiency` column, not just on the initial render.
  """

  @type sort_by :: :student_name | :proficiency | :activity_completion
  @type column :: %{
          required(:key) => sort_by(),
          required(:label) => String.t(),
          optional(:tooltip) => String.t()
        }

  @sortable_columns [:student_name, :proficiency, :activity_completion]
  @default_sort_by :proficiency

  # Tooltip copy reused verbatim from existing, already-approved copy elsewhere in this
  # feature area (not new copy): the Proficiency tooltip matches
  # `OliWeb.Delivery.LearningObjectives.ObjectivesTableModel`'s "Student Proficiency" column;
  # the Activities tooltip matches the "Activities Attempted" column this table supersedes.
  @columns [
    %{key: :student_name, label: "Student Name"},
    %{
      key: :proficiency,
      label: "Proficiency",
      tooltip:
        "Proficiency is based on the percentage of correct answers on first attempts for " <>
          "activities linked to this learning objective or its sub-objectives."
    },
    %{
      key: :activity_completion,
      label: "Activities",
      tooltip:
        "The number of activities linked to this learning objective that the student has " <>
          "tried at least once, compared to the total tied to this learning objective."
    }
  ]

  @proficiency_order %{
    needs_support: ["Low", "Medium", "High", "Not enough data"],
    excelling: ["Medium", "High", "Low", "Not enough data"],
    limited_activity: ["Not enough data", "Low", "Medium", "High"]
  }

  @doc "Column key/label pairs, in display order."
  @spec columns() :: [column()]
  def columns, do: @columns

  @doc "Column keys this model accepts as a `sort_by` value."
  @spec sortable_columns() :: [sort_by()]
  def sortable_columns, do: @sortable_columns

  @doc "The column sorted by default."
  @spec default_sort_by() :: sort_by()
  def default_sort_by, do: @default_sort_by

  @doc """
  Sorts `students` (already filtered to one distribution group by the caller) by `sort_by`
  and `sort_order`. `sort_by` falls back to #{inspect(@default_sort_by)} if it isn't one of
  #{inspect(@sortable_columns)}.
  """
  @spec sort(
          [map()],
          Oli.Delivery.Metrics.StudentDistributionGroup.group(),
          sort_by(),
          :asc | :desc
        ) :: [map()]
  def sort(students, group, sort_by \\ @default_sort_by, sort_order \\ :asc) do
    sort_by = if sort_by in @sortable_columns, do: sort_by, else: @default_sort_by

    Enum.sort_by(students, sort_key_fn(group, sort_by), sort_order)
  end

  defp sort_key_fn(_group, :student_name), do: &(&1.full_name || "")
  defp sort_key_fn(_group, :activity_completion), do: &(Map.get(&1, :activity_completion) || 0.0)

  # Needs Support defaults low-first, Excelling defaults medium-first, Limited Activity
  # defaults to the full Not Enough Info -> Low -> Medium -> High order. Unknown/missing
  # labels sort last. Applies whenever sorting by this column, not only on initial render.
  defp sort_key_fn(group, :proficiency) do
    order = Map.fetch!(@proficiency_order, group)

    fn student ->
      label = Map.get(student, :proficiency_range) || "Not enough data"
      Enum.find_index(order, &(&1 == label)) || length(order)
    end
  end
end
