defmodule Oli.Analytics.Datasets.Settings do
  def emr_application_name do
    Application.get_env(:oli, :dataset_generation)[:emr_application_name]
  end

  def execution_role do
    Application.get_env(:oli, :dataset_generation)[:execution_role]
  end

  def entry_point do
    Application.get_env(:oli, :dataset_generation)[:entry_point]
  end

  def log_uri do
    Application.get_env(:oli, :dataset_generation)[:log_uri]
  end

  def source_bucket do
    Application.get_env(:oli, :dataset_generation)[:source_bucket]
  end

  def context_bucket do
    Application.get_env(:oli, :dataset_generation)[:context_bucket]
  end

  def spark_submit_parameters do
    Application.get_env(:oli, :dataset_generation)[:spark_submit_parameters]
  end

  def region() do
    :ex_aws
    |> Application.get_env(:s3, [])
    |> Keyword.get(:region)
    |> resolve_config_value()
  end

  def enabled?() do
    Application.get_env(:oli, :dataset_generation)[:enabled]
  end

  defp resolve_config_value({:system, env_var}) do
    System.get_env(env_var)
  end

  defp resolve_config_value({:system, env_var, default}) do
    System.get_env(env_var) || default
  end

  defp resolve_config_value(value) when is_list(value) do
    value
    |> Enum.reduce_while(nil, fn entry, acc ->
      case resolve_config_value(entry) do
        resolved when is_binary(resolved) and resolved != "" -> {:halt, resolved}
        resolved when resolved in [nil, ""] -> {:cont, acc}
        resolved -> {:halt, resolved}
      end
    end)
  end

  defp resolve_config_value(value), do: value
end
