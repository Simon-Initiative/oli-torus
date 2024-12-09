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

  def spark_submit_parameters do
    Application.get_env(:oli, :dataset_generation)[:spark_submit_parameters]
  end

  def region() do
    Application.get_env(:ex_aws, :s3)[:region]
  end
end
