defmodule Oli.LearningModel.Config do
  @moduledoc """
  Typed, startup-loaded global configuration for LKT-AOA.

  Environment parsing is injectable so tests can exercise runtime behavior
  without mutating the process environment.
  """

  require Logger

  alias Oli.LearningModel.Parameters

  @gamma_env "LKT_AOA_GAMMA"
  @rho_env "LKT_AOA_RHO"
  @recency_decay_env "LKT_AOA_RECENCY_DECAY"
  @confidence_saturation_env "LKT_AOA_CONFIDENCE_SATURATION"
  @defaults Application.compile_env!(:oli, :lkt_aoa)

  @enforce_keys [:gamma, :rho, :recency_decay, :confidence_saturation]
  defstruct [:gamma, :rho, :recency_decay, :confidence_saturation]

  @type t :: %__MODULE__{
          gamma: float(),
          rho: float(),
          recency_decay: float(),
          confidence_saturation: float()
        }

  @type source :: :default | :override
  @type sources :: %{required(atom()) => source()}
  @type env_reader :: (String.t() -> String.t() | nil)

  @spec defaults() :: t()
  def defaults, do: new!(@defaults)

  @spec load_from_env!(env_reader()) :: {t(), sources()}
  def load_from_env!(get_env \\ &System.get_env/1) when is_function(get_env, 1) do
    base = Application.get_env(:oli, :lkt_aoa, @defaults)
    load_from_env!(base, get_env)
  end

  @spec load_from_env!(map() | keyword() | t(), env_reader()) :: {t(), sources()}
  def load_from_env!(base, get_env) when is_function(get_env, 1) do
    base = base |> new!() |> Map.from_struct()

    definitions = [
      {:gamma, @gamma_env},
      {:rho, @rho_env},
      {:recency_decay, @recency_decay_env},
      {:confidence_saturation, @confidence_saturation_env}
    ]

    {values, sources} =
      Enum.reduce(definitions, {base, %{}}, fn {key, env_name}, {values, sources} ->
        case get_env.(env_name) do
          nil ->
            {values, Map.put(sources, key, :default)}

          raw_value ->
            value = parse_env_value!(raw_value, env_name, key)
            {Map.put(values, key, value), Map.put(sources, key, :override)}
        end
      end)

    {new!(values), sources}
  end

  @spec new!(map() | keyword() | t()) :: t()
  def new!(%__MODULE__{} = config), do: validate!(config)

  def new!(values) when is_list(values), do: values |> Map.new() |> new!()

  def new!(values) when is_map(values) do
    %__MODULE__{
      gamma: Map.fetch!(values, :gamma),
      rho: Map.fetch!(values, :rho),
      recency_decay: Map.fetch!(values, :recency_decay),
      confidence_saturation: Map.fetch!(values, :confidence_saturation)
    }
    |> normalize!()
    |> validate!()
  end

  @spec fetch!() :: t()
  def fetch! do
    :oli
    |> Application.fetch_env!(:lkt_aoa)
    |> new!()
  end

  @spec to_keyword(t()) :: keyword(float())
  def to_keyword(%__MODULE__{} = config) do
    [
      gamma: config.gamma,
      rho: config.rho,
      recency_decay: config.recency_decay,
      confidence_saturation: config.confidence_saturation
    ]
  end

  @spec log_effective(t(), sources()) :: :ok
  def log_effective(%__MODULE__{} = config, sources) do
    Logger.info(
      "Loaded LKT-AOA configuration " <>
        "gamma=#{config.gamma} (#{Map.fetch!(sources, :gamma)}), " <>
        "rho=#{config.rho} (#{Map.fetch!(sources, :rho)}), " <>
        "recency_decay=#{config.recency_decay} (#{Map.fetch!(sources, :recency_decay)}), " <>
        "confidence_saturation=#{config.confidence_saturation} " <>
        "(#{Map.fetch!(sources, :confidence_saturation)})"
    )
  end

  defp parse_env_value!(raw_value, env_name, key) when is_binary(raw_value) do
    case Float.parse(String.trim(raw_value)) do
      {value, ""} -> validate_value!(key, value, env_name)
      _ -> raise ArgumentError, "#{env_name} must be a finite number"
    end
  end

  defp parse_env_value!(_raw_value, env_name, _key),
    do: raise(ArgumentError, "#{env_name} must be a finite number")

  defp normalize!(config) do
    %__MODULE__{
      gamma: normalize_number!(config.gamma, :gamma),
      rho: normalize_number!(config.rho, :rho),
      recency_decay: normalize_number!(config.recency_decay, :recency_decay),
      confidence_saturation:
        normalize_number!(config.confidence_saturation, :confidence_saturation)
    }
  end

  defp normalize_number!(number, key) do
    case Parameters.to_finite_float(number) do
      {:ok, number} -> number
      :error -> raise ArgumentError, "#{key} must be a finite number"
    end
  end

  defp validate!(config) do
    validate_value!(:gamma, config.gamma, :gamma)
    validate_value!(:rho, config.rho, :rho)
    validate_value!(:recency_decay, config.recency_decay, :recency_decay)
    validate_value!(:confidence_saturation, config.confidence_saturation, :confidence_saturation)
    config
  end

  defp validate_value!(key, value, name) do
    if not Parameters.finite_number?(value) do
      raise ArgumentError, "#{name} must be a finite number"
    end

    case key do
      key when key in [:gamma, :rho] and value < 0.0 ->
        raise ArgumentError, "#{name} must be greater than or equal to 0.0"

      :recency_decay when value <= 0.0 or value > 1.0 ->
        raise ArgumentError, "#{name} must be greater than 0.0 and at most 1.0"

      :confidence_saturation when value <= 0.0 ->
        raise ArgumentError, "#{name} must be greater than 0.0"

      _ ->
        value
    end
  end
end
