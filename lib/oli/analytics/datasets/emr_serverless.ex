defmodule Oli.Analytics.Datasets.EmrServerless do

  @moduledoc """
  Module for interacting with the EMR serverless environment.  The ExAws library does not
  support EMR Servless, but we use some of its building blocks (specifically authorization
  header signing) to interact with the EMR serverless API.

  Documentation for the EMR serverless API can be found at:
  https://docs.aws.amazon.com/pdfs/emr-serverless/latest/APIReference/emr-serverless-api.pdf

  """

  alias ExAws.Auth
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.Utils
  alias Oli.Analytics.Datasets.Settings
  alias ExAws.S3
  alias ExAws

  require Logger


  @doc """
  Issues a GET request to the EMR serverless endpoint to list all available applications.

  Returns {:ok, json} if the request is successful, where json is the response body
  parsed as a map.  Otherwise, returns the error response from the HTTPoison library.
  """
  def list_applications() do

    config = ExAws.Config.new(:s3) |> Map.put(:host, "emr-serverless.#{Settings.region()}.amazonaws.com")

    # Construct the URL for the "applications" EMR serverless endpoint
    base_url = "https://emr-serverless.#{Settings.region()}.amazonaws.com/applications"
    query_params = "maxResults=50"
    url = "#{base_url}?#{query_params}"

    # Generate signed headers, using the ExAws.Auth module
    {:ok, signed_headers} =
      Auth.headers(
        :get,
        url,
        String.to_atom("emr-serverless"),
        config,
        [],
        ""
      )

    # Send the HTTP request
    case HTTPoison.get(url, signed_headers) do
      {:ok, response} ->
        {:ok, Poison.decode!(response.body)}

      e -> e
    end
  end

  def get_jobs(application_id), do: get_jobs(application_id, [], nil)

  def get_jobs(application_id, results, next_token) do

    config = ExAws.Config.new(:s3) |> Map.put(:host, "emr-serverless.#{Settings.region()}.amazonaws.com")

    # Construct the URL for the "applications" EMR serverless endpoint
    base_url = "https://emr-serverless.#{Settings.region()}.amazonaws.com/applications/#{application_id}/jobruns"
    query_params = "maxResults=50"

    query_params = case next_token do
      nil -> query_params
      _ -> "#{query_params}&nextToken=#{next_token}"
    end
    url = "#{base_url}?#{query_params}"

    # Generate signed headers, using the ExAws.Auth module
    {:ok, signed_headers} =
      Auth.headers(
        :get,
        url,
        String.to_atom("emr-serverless"),
        config,
        [],
        ""
      )

    # Send the HTTP request
    case HTTPoison.get(url, signed_headers) do
      {:ok, response} ->

        json = Poison.decode!(response.body)

        case Map.get(json, "nextToken") do
          nil -> {:ok, results ++ json["jobRuns"]}

          token ->
            get_jobs(application_id, results ++ json["jobRuns"], token)
        end

      e -> e
    end

  end




  @doc """
  Issues a POST request to the EMR serverless endpoint to submit a job. Returns {:ok, job} if the
  request is successful, where job is the DatasetJob struct with the job_run_id field populated.
  Otherwise, returns the error response from the HTTPoison library.
  """
  def submit_job(%DatasetJob{} = job) do
    region = Settings.region()

    config = ExAws.Config.new(:s3) |> Map.put(:host, "emr-serverless.#{region}.amazonaws.com")

    # Construct the URL for the "applications" EMR serverless endpoint
    url = "https://emr-serverless.#{region}.amazonaws.com/applications/#{job.application_id}/jobruns"

    arguments = [
      "--bucket_name",
      Settings.source_bucket(),
      "--chunk_size",
      "#{job.configuration.chunk_size}",
      "--sub_types",
      "#{if job.job_type == :datashop, do: "datashop", else: job.configuration.event_sub_types}",
      "--job_id",
      "#{job.job_id}",
      "--section_ids",
      "#{job.configuration.section_ids |> to_str}",
      "--action",
      "#{if job.job_type == :datashop, do: "datashop", else: job.configuration.event_type}",
      "--enforce_project_id",
      "#{job.project_id}"
    ]

    arguments = case {job.job_type, Enum.count(job.configuration.excluded_fields)} do
      {:datashop, _} -> arguments
      {_, 0} -> arguments
      _ -> arguments ++ ["--exclude_fields", job.configuration.excluded_fields |> to_str]
    end

    arguments = case Enum.count(job.configuration.ignored_student_ids) do
      0 -> arguments
      _ -> arguments ++ ["--ignored_student_ids", "#{job.configuration.ignored_student_ids |> to_str}"]
    end

    body = %{
      "clientToken" => job.job_id,
      "applicationId" => job.application_id,
      "executionRoleArn" => Settings.execution_role(),
      "jobDriver" => %{
        "sparkSubmit" => %{
          "entryPoint" => Settings.entry_point(),
          "entryPointArguments" => arguments,
          "sparkSubmitParameters" => Settings.spark_submit_parameters()
        }
      },
      "configurationOverrides" => %{
        "monitoringConfiguration" => %{
          "s3MonitoringConfiguration" => %{
            "logUri" => Settings.log_uri()
          }
        }
      }
    }

    # Generate signed headers, using the ExAws.Auth module
    {:ok, signed_headers} =
      Auth.headers(
        :post,
        url,
        String.to_atom("emr-serverless"),
        config,
        [],
        Poison.encode!(body)
      )

    # Send the HTTP request
    case HTTPoison.post(url, Poison.encode!(body), signed_headers) do
      {:ok, response} ->
        # Parse the response and extract the job run id
        json = Poison.decode!(response.body)
        job = %DatasetJob{job | job_run_id: json["jobRunId"]}
        {:ok, job}
      e -> e
    end
  end


  defp to_str(list) do
    Enum.join(list, ",")
  end


end
