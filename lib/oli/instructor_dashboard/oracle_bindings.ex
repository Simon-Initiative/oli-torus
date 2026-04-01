defmodule Oli.InstructorDashboard.OracleBindings do
  @moduledoc """
  Instructor capability-to-oracle bindings for lane-1 data contracts.

  This module intentionally supports provisional mappings so shared contracts can
  be exercised before tile stories finalize concrete oracle payloads.

  Extension workflow:
  1. Add a concrete oracle module implementing `Oli.Dashboard.Oracle`.
  2. Add an oracle key -> module entry under `bindings/0` `:oracles`.
  3. Add/update a consumer entry under `bindings/0` `:consumers`.
  4. Run registry validation and contract tests.
  """

  alias Oli.InstructorDashboard.Oracles.Grades
  alias Oli.InstructorDashboard.Oracles.ObjectivesProficiency
  alias Oli.InstructorDashboard.Oracles.Placeholder.Engagement
  alias Oli.InstructorDashboard.Oracles.Placeholder.Progress
  alias Oli.InstructorDashboard.Oracles.ProgressBins
  alias Oli.InstructorDashboard.Oracles.ProgressProficiency
  alias Oli.InstructorDashboard.Oracles.SectionAnalytics
  alias Oli.InstructorDashboard.Oracles.ScopeResources
  alias Oli.InstructorDashboard.Oracles.StudentInfo

  @type consumer_key :: atom()
  @type oracle_key :: atom()
  @type slot :: atom()

  @type consumer_binding :: %{
          required_oracles: %{optional(slot()) => oracle_key()},
          optional_oracles: %{optional(slot()) => oracle_key()}
        }

  @type t :: %{
          consumers: %{optional(consumer_key()) => consumer_binding()},
          oracles: %{optional(oracle_key()) => module()}
        }

  @type error :: {:unknown_consumer, consumer_key()}

  @spec bindings() :: t()
  def bindings do
    %{
      consumers: %{
        progress_summary: %{
          required_oracles: %{
            progress: :oracle_instructor_progress
          },
          optional_oracles: %{
            engagement: :oracle_instructor_engagement
          }
        },
        support_summary: %{
          required_oracles: %{
            progress_proficiency: :oracle_instructor_progress_proficiency,
            student_info: :oracle_instructor_student_info
          },
          optional_oracles: %{}
        },
        assessments_summary: %{
          required_oracles: %{
            grades: :oracle_instructor_grades,
            scope_resources: :oracle_instructor_scope_resources
          },
          optional_oracles: %{}
        },
        challenging_objectives: %{
          required_oracles: %{
            objectives_proficiency: :oracle_instructor_objectives_proficiency,
            scope_resources: :oracle_instructor_scope_resources
          },
          optional_oracles: %{}
        },
        legacy_section_analytics: %{
          required_oracles: %{
            section_analytics: :oracle_instructor_section_analytics
          },
          optional_oracles: %{}
        }
      },
      oracles: %{
        oracle_instructor_progress: Progress,
        oracle_instructor_engagement: Engagement,
        oracle_instructor_section_analytics: SectionAnalytics,
        oracle_instructor_progress_bins: ProgressBins,
        oracle_instructor_progress_proficiency: ProgressProficiency,
        oracle_instructor_student_info: StudentInfo,
        oracle_instructor_scope_resources: ScopeResources,
        oracle_instructor_grades: Grades,
        oracle_instructor_objectives_proficiency: ObjectivesProficiency
      }
    }
  end

  @spec binding_for(consumer_key()) :: {:ok, consumer_binding()} | {:error, error()}
  def binding_for(consumer_key) when is_atom(consumer_key) do
    case get_in(bindings(), [:consumers, consumer_key]) do
      nil -> {:error, {:unknown_consumer, consumer_key}}
      binding -> {:ok, binding}
    end
  end

  def binding_for(consumer_key), do: {:error, {:unknown_consumer, consumer_key}}

  @spec consumer_profiles() :: %{
          optional(consumer_key()) => %{required: [oracle_key()], optional: [oracle_key()]}
        }
  def consumer_profiles do
    bindings()
    |> Map.fetch!(:consumers)
    |> Enum.into(%{}, fn {consumer_key,
                          %{required_oracles: required_slots, optional_oracles: optional_slots}} ->
      {consumer_key,
       %{
         required: canonical_oracle_keys(required_slots),
         optional: canonical_oracle_keys(optional_slots)
       }}
    end)
  end

  @spec oracle_modules() :: %{optional(oracle_key()) => module()}
  def oracle_modules, do: bindings() |> Map.fetch!(:oracles)

  defp canonical_oracle_keys(slot_map) do
    slot_map
    |> Map.values()
    |> Enum.uniq()
    |> Enum.sort()
  end
end
