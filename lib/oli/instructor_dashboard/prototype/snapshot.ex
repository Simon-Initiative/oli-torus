defmodule Oli.InstructorDashboard.Prototype.Snapshot do
  @moduledoc """
  Prototype snapshot builder that loads oracles and derives tile projections.
  """

  alias Oli.InstructorDashboard.Prototype.TileRegistry

  @enforce_keys [:scope, :oracle_payloads, :oracle_statuses, :projections, :projection_statuses]
  defstruct [:scope, :oracle_payloads, :oracle_statuses, :projections, :projection_statuses]

  @type t :: %__MODULE__{
          scope: Oli.InstructorDashboard.Prototype.Scope.t(),
          oracle_payloads: %{atom() => term()},
          oracle_statuses: %{atom() => :ready | {:error, term()}},
          projections: %{atom() => map()},
          projection_statuses: %{atom() => :ready | {:error, term()}}
        }

  def build(scope, tiles \\ TileRegistry.tiles(), opts \\ []) do
    with {:ok, oracle_modules} <- TileRegistry.resolve_oracles(tiles) do
      {oracle_payloads, oracle_statuses} = load_oracles(scope, oracle_modules, opts)
      project(scope, tiles, oracle_payloads, oracle_statuses)
    end
  end

  def project(scope, tiles, oracle_payloads, oracle_statuses) do
    snapshot = %__MODULE__{
      scope: scope,
      oracle_payloads: oracle_payloads,
      oracle_statuses: oracle_statuses,
      projections: %{},
      projection_statuses: %{}
    }

    {projections, projection_statuses} = TileRegistry.project_all(snapshot, tiles)
    {:ok, %{snapshot | projections: projections, projection_statuses: projection_statuses}}
  end

  def fetch_oracle(%__MODULE__{} = snapshot, oracle_module) do
    key = oracle_module.key()

    case Map.fetch(snapshot.oracle_payloads, key) do
      {:ok, payload} -> {:ok, payload}
      :error -> {:error, {:oracle_missing, key}}
    end
  end

  def oracle_status(%__MODULE__{} = snapshot, oracle_module) do
    key = oracle_module.key()
    Map.get(snapshot.oracle_statuses, key, {:error, :missing})
  end

  defp load_oracles(scope, oracle_modules, opts) do
    skip_optional = MapSet.new(Keyword.get(opts, :skip_optional, []))

    Enum.reduce(oracle_modules, {%{}, %{}}, fn {oracle_key, module, optional?},
                                               {payloads, statuses} ->
      if optional? and MapSet.member?(skip_optional, oracle_key) do
        {payloads, Map.put(statuses, oracle_key, {:error, :skipped_optional})}
      else
        case module.load(scope, []) do
          {:ok, payload} ->
            {Map.put(payloads, oracle_key, payload), Map.put(statuses, oracle_key, :ready)}

          {:error, reason} ->
            {payloads, Map.put(statuses, oracle_key, {:error, reason})}
        end
      end
    end)
  end
end
