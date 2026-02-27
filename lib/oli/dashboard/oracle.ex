defmodule Oli.Dashboard.Oracle do
  @moduledoc """
  Shared behavior contract for dashboard oracle modules.

  Oracle modules are the sanctioned query boundary for dashboard domains.
  Oracle implementations must not call peer oracle modules directly. Any
  prerequisite orchestration is handled by registry/runtime layers.
  """

  alias Oli.Dashboard.OracleContext

  @type oracle_key :: atom()
  @type payload :: map() | term()
  @type reason :: term()

  @callback key() :: oracle_key()
  @callback version() :: non_neg_integer()
  @callback requires() :: [oracle_key()]
  @callback load(OracleContext.t(), keyword()) :: {:ok, payload()} | {:error, reason()}
  @callback project(payload(), keyword()) :: term()

  @optional_callbacks requires: 0, project: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Oli.Dashboard.Oracle

      @impl true
      def requires, do: []

      defoverridable requires: 0
    end
  end
end
