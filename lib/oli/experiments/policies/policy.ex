defmodule Oli.Experiments.Policies.Policy do
  @moduledoc """
  Common contract for experiment assignment and reward policies.
  """

  alias Oli.Experiments.Policies.{PolicyAssignment, PolicyUpdate}

  @callback assign(map(), map() | nil, map()) ::
              {:ok, PolicyAssignment.t()} | {:error, term()}

  @callback record_reward(map(), map() | nil, map()) ::
              {:ok, PolicyUpdate.t()} | {:error, term()}
end
