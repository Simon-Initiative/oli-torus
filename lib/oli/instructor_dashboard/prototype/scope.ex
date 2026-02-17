defmodule Oli.InstructorDashboard.Prototype.Scope do
  @moduledoc """
  Prototype scope model carrying the global filter and container selection.
  """

  @enforce_keys [:context_type, :context_id, :container_type, :container_id, :filters]
  defstruct [:context_type, :context_id, :container_type, :container_id, :filters]

  @type container_type :: :course | :unit | :module

  @type t :: %__MODULE__{
          context_type: :section,
          context_id: pos_integer(),
          container_type: container_type(),
          container_id: pos_integer() | nil,
          filters: map()
        }

  def new(opts \\ %{}) do
    opts = Map.new(opts)

    %__MODULE__{
      context_type: Map.get(opts, :context_type, :section),
      context_id: Map.get(opts, :context_id, 1),
      container_type: Map.get(opts, :container_type, :course),
      container_id: Map.get(opts, :container_id, nil),
      filters: Map.get(opts, :filters, default_filters())
    }
  end

  def default_filters do
    %{
      completion_threshold: 80,
      progress_bin_size: 10,
      student_support_rules: %{
        struggling: %{any: [{:progress, :lt, 40}, {:proficiency, :lt, 40}], all: []},
        excelling: %{any: [], all: [{:progress, :gte, 80}, {:proficiency, :gte, 80}]},
        on_track: %{any: [], all: [{:progress, :gte, 40}, {:proficiency, :gte, 40}]}
      }
    }
  end
end
