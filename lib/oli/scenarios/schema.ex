defmodule Oli.Scenarios.Schema do
  @moduledoc """
  JSON Schema-backed validation for Oli.Scenarios YAML files.

  This module validates structural correctness (supported directives, allowed
  attributes, and value shapes) before directives are parsed/executed.
  """

  @schema_name "scenario.schema.json"
  @schema_path "#{:code.priv_dir(:oli)}/schemas/v0-1-0/#{@schema_name}"

  @external_resource @schema_path
  @raw_schema @schema_path |> File.read!() |> Jason.decode!()
  @resolved_schema ExJsonSchema.Schema.resolve(@raw_schema)

  @type validation_error :: %{message: String.t(), path: String.t()}

  @spec schema() :: map()
  def schema, do: @raw_schema

  @spec validate_data(term()) :: :ok | {:error, [validation_error()]}
  def validate_data(data) do
    case ExJsonSchema.Validator.validate(@resolved_schema, data) do
      :ok ->
        :ok

      {:error, errors} ->
        {:error, format_errors(errors)}
    end
  end

  @spec validate_yaml(String.t()) :: :ok | {:error, [validation_error()]}
  def validate_yaml(yaml_content) when is_binary(yaml_content) do
    yaml_content
    |> YamlElixir.read_from_string!()
    |> validate_data()
  end

  @spec validate_file(String.t()) :: :ok | {:error, [validation_error()]}
  def validate_file(path) when is_binary(path) do
    path
    |> File.read!()
    |> validate_yaml()
  end

  defp format_errors(errors) do
    Enum.map(errors, fn {message, path} ->
      %{
        message: normalize_message(message),
        path: normalize_path(path)
      }
    end)
  end

  defp normalize_message(message) when is_binary(message), do: message
  defp normalize_message(message), do: inspect(message)

  defp normalize_path(path) when is_binary(path), do: path
  defp normalize_path(path), do: inspect(path)
end
