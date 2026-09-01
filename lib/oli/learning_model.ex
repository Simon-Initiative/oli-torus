defmodule Oli.LearningModel do
  @moduledoc """
  Public delivery-side learning-model application boundary.

  The caller supplies a loaded Section and the evaluated-attempt group already
  constructed by the Snapshot/Summary path. This module only dispatches by the
  Section's pinned semantic model version; model-specific persistence lives in
  narrower implementation modules.
  """

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Delivery.Sections.Section
  alias Oli.LearningModel.Config
  alias Oli.LearningModel.LktAoa.{Application, BatchResult}

  @type application_error :: term()

  @spec apply_evaluated_attempts(Section.t(), AttemptGroup.t() | nil) ::
          {:ok, BatchResult.t()} | {:error, application_error()}
  def apply_evaluated_attempts(%Section{} = _section, nil) do
    {:ok, BatchResult.new(:noop)}
  end

  def apply_evaluated_attempts(%Section{learning_model_version: :naive}, %AttemptGroup{} = group) do
    {:ok, BatchResult.new(:skipped, input_attempt_count: length(group.part_attempts || []))}
  end

  def apply_evaluated_attempts(
        %Section{learning_model_version: :lkt_aoa} = section,
        %AttemptGroup{} = group
      ) do
    # Fetch once at the public LKT boundary, then pass the immutable typed config
    # through every pure transition so reductions never read runtime environment state.
    Application.apply(section, group, Config.fetch!())
  end

  def apply_evaluated_attempts(%Section{learning_model_version: version}, %AttemptGroup{}) do
    {:error, {:unsupported_learning_model_version, version}}
  end
end
