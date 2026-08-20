defmodule Oli.LearningModel.Parameters do
  @moduledoc """
  Version-neutral, typed envelope for learning-model parameters.

  The persisted JSON representation is self-describing. Decoding dispatches on
  the schema version, model version, and parameter type instead of exposing raw
  maps to consumers.
  """

  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}

  @enforce_keys [:schema_version, :model, :model_version, :parameter_type, :payload]
  defstruct [:schema_version, :model, :model_version, :parameter_type, :payload]

  @type parameter_type :: :learning_objective | :activity
  @type payload :: LearningObjectiveParameters.t() | ActivityParameters.t()

  @type t :: %__MODULE__{
          schema_version: pos_integer(),
          model: :lkt_aoa,
          model_version: pos_integer(),
          parameter_type: parameter_type(),
          payload: payload()
        }

  @spec decode(term()) :: {:ok, t() | nil} | {:error, term()}
  def decode(nil), do: {:ok, nil}

  def decode(%__MODULE__{} = parameters) do
    parameters
    |> Map.from_struct()
    |> decode()
  end

  def decode(parameters) when is_map(parameters) do
    with {:ok, schema_version} <- fetch(parameters, :schema_version),
         :ok <- validate_schema_version(schema_version),
         {:ok, model} <- fetch(parameters, :model),
         :ok <- validate_model(model),
         {:ok, model_version} <- fetch(parameters, :model_version),
         :ok <- validate_model_version(model_version),
         {:ok, parameter_type} <- fetch(parameters, :parameter_type),
         {:ok, normalized_type} <- normalize_parameter_type(parameter_type),
         {:ok, payload} <- fetch(parameters, :payload),
         {:ok, normalized_payload} <- decode_payload(normalized_type, payload) do
      {:ok,
       %__MODULE__{
         schema_version: 1,
         model: :lkt_aoa,
         model_version: 2,
         parameter_type: normalized_type,
         payload: normalized_payload
       }}
    end
  end

  def decode(_parameters), do: {:error, {:invalid_parameter_envelope, :expected_map}}

  @spec encode(term()) :: {:ok, map() | nil} | {:error, term()}
  def encode(parameters) do
    with {:ok, normalized} <- decode(parameters) do
      {:ok, encode_normalized(normalized)}
    end
  end

  @spec finite_number?(term()) :: boolean()
  def finite_number?(number), do: match?({:ok, _number}, to_finite_float(number))

  @spec to_finite_float(term()) :: {:ok, float()} | :error
  def to_finite_float(number) when is_integer(number) do
    try do
      {:ok, number / 1}
    rescue
      ArithmeticError -> :error
    end
  end

  def to_finite_float(number) when is_float(number) do
    encoded = number |> :erlang.float_to_binary([:compact]) |> String.downcase()

    if encoded in ["nan", "inf", "-inf"], do: :error, else: {:ok, number}
  end

  def to_finite_float(_number), do: :error

  defp fetch(map, key) do
    string_key = Atom.to_string(key)

    case Map.fetch(map, string_key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(map, key) |> normalize_fetch_error(key)
    end
  end

  defp normalize_fetch_error({:ok, value}, _key), do: {:ok, value}
  defp normalize_fetch_error(:error, key), do: {:error, {:missing_parameter_field, key}}

  defp validate_schema_version(1), do: :ok
  defp validate_schema_version(version), do: {:error, {:unsupported_schema_version, version}}

  defp validate_model(:lkt_aoa), do: :ok
  defp validate_model("lkt_aoa"), do: :ok
  defp validate_model(model), do: {:error, {:unsupported_model, model}}

  defp validate_model_version(2), do: :ok
  defp validate_model_version(version), do: {:error, {:unsupported_model_version, version}}

  defp normalize_parameter_type(:learning_objective), do: {:ok, :learning_objective}
  defp normalize_parameter_type("learning_objective"), do: {:ok, :learning_objective}
  defp normalize_parameter_type(:activity), do: {:ok, :activity}
  defp normalize_parameter_type("activity"), do: {:ok, :activity}

  defp normalize_parameter_type(parameter_type),
    do: {:error, {:unsupported_parameter_type, parameter_type}}

  defp decode_payload(:learning_objective, %LearningObjectiveParameters{} = payload) do
    decode_learning_objective_payload(Map.from_struct(payload))
  end

  defp decode_payload(:learning_objective, payload) when is_map(payload),
    do: decode_learning_objective_payload(payload)

  defp decode_payload(:learning_objective, _payload),
    do: {:error, {:invalid_parameter_payload, :learning_objective}}

  defp decode_payload(:activity, %ActivityParameters{} = payload),
    do: decode_activity_payload(Map.from_struct(payload))

  defp decode_payload(:activity, payload) when is_map(payload),
    do: decode_activity_payload(payload)

  defp decode_payload(:activity, _payload),
    do: {:error, {:invalid_parameter_payload, :activity}}

  defp decode_learning_objective_payload(payload) do
    with {:ok, beta_lo} <- fetch(payload, :beta_lo),
         {:ok, beta_lo} <- normalize_number(beta_lo, :beta_lo) do
      {:ok, %LearningObjectiveParameters{beta_lo: beta_lo}}
    end
  end

  defp decode_activity_payload(payload) do
    with {:ok, parts} <- fetch(payload, :parts),
         {:ok, parts} <- decode_parts(parts) do
      {:ok, %ActivityParameters{parts: parts}}
    end
  end

  defp decode_parts(parts) when is_map(parts) do
    Enum.reduce_while(parts, {:ok, %{}}, fn {part_id, parameters}, {:ok, decoded} ->
      with :ok <- validate_part_id(part_id),
           {:ok, part_parameters} <- decode_part_parameters(part_id, parameters) do
        {:cont, {:ok, Map.put(decoded, part_id, part_parameters)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp decode_parts(_parts), do: {:error, {:invalid_parameter_payload, :parts}}

  defp validate_part_id(part_id) when is_binary(part_id) and part_id != "", do: :ok
  defp validate_part_id(part_id), do: {:error, {:invalid_part_id, part_id}}

  defp decode_part_parameters(part_id, %PartParameters{} = parameters),
    do: decode_part_parameters(part_id, Map.from_struct(parameters))

  defp decode_part_parameters(part_id, parameters) when is_map(parameters) do
    with {:ok, beta_difficulty} <- fetch(parameters, :beta_difficulty),
         {:ok, beta_difficulty} <-
           normalize_number(beta_difficulty, {:beta_difficulty, part_id}) do
      {:ok, %PartParameters{beta_difficulty: beta_difficulty}}
    end
  end

  defp decode_part_parameters(part_id, _parameters),
    do: {:error, {:invalid_part_parameters, part_id}}

  defp normalize_number(number, field) do
    case to_finite_float(number) do
      {:ok, number} -> {:ok, number}
      :error -> {:error, {:invalid_finite_number, field}}
    end
  end

  defp encode_normalized(nil), do: nil

  defp encode_normalized(%__MODULE__{
         schema_version: 1,
         model: :lkt_aoa,
         model_version: 2,
         parameter_type: parameter_type,
         payload: payload
       }) do
    %{
      "schema_version" => 1,
      "model" => "lkt_aoa",
      "model_version" => 2,
      "parameter_type" => Atom.to_string(parameter_type),
      "payload" => encode_payload(payload)
    }
  end

  defp encode_payload(%LearningObjectiveParameters{beta_lo: beta_lo}),
    do: %{"beta_lo" => beta_lo}

  defp encode_payload(%ActivityParameters{parts: parts}) do
    %{
      "parts" =>
        Map.new(parts, fn {part_id, %PartParameters{beta_difficulty: beta_difficulty}} ->
          {part_id, %{"beta_difficulty" => beta_difficulty}}
        end)
    }
  end
end
