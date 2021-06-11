defmodule Oli.Delivery.Evaluation.AdaptiveResult do
  @derive Jason.Encoder
  defstruct [:type, :params, :error, :attempt_guid]

  def parse(result, attempt_guid) do
    {:ok,
      %Oli.Delivery.Evaluation.AdaptiveResult{
        attempt_guid: attempt_guid,
        type: result.type,
        params: %{
          order: result.params.order,
          correct: result.params.correct,
          actions: result.params.actions
        }
      }}
  end
end
