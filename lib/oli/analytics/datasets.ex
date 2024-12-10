defmodule Oli.Analytics.Datasets do

  alias Oli.Analytics.Datasets.JobConfig
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.Utils
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets.EmrServerless
  alias ExAws.S3
  alias ExAws
  alias Oli.Repo

  require Logger


  @doc """
  Creates a new dataset creation job, submitting to the EMR serverless
  environment for processing.  This is a four step process:

  1. Initiaze the job with the provided configuration, generating a unique job ID
  2. Preprocess the job configuration, depending on the job type
  3. Submit the job to the EMR serverless environment
  4. Persist the job to the database

  Any of steps 2-4 can fail, in which case the job will not be persisted to the database
  and an error will be returned.  The error will be logged to the console. If the job
  submission fails in step 3, it is okay that the context had been successfully
  staged in step 2, as the staging is done in a way that is idempotent for job ids, but more
  importantly, retries of the entire job creation process results in a new context
  being staged in S3 for a new job id.

  ## Examples

      iex> Datasets.create_job(:datashop, 1, 2, %JobConfig{chunk_size: 10_000})
      {:ok, %DatasetJob{...}}

      iex> Datasets.create_job(:custom, 1, 2, %JobConfig{excluded_fields: [:response]})
      {:ok, %DatasetJob{...}}
  """
  def create_job(job_type, project_id, initiated_by_id, %JobConfig{} = config) do

    with {:ok, job} <- init(job_type, project_id, initiated_by_id, config),
      {:ok, job} <- preprocess(job),
      {:ok, job} <- submit(job),
      {:ok, job} <- persist(job) do
        {:ok, job}
    else
      {:error, e} ->
        Logger.error("Failed to create job #{Kernel.to_string(e)}")
        e
    end

  end

  defp init(job_type, project_id, initiated_by_id, %JobConfig{} = config) do
    job = %DatasetJob{
      project_id: project_id,
      initiated_by_id: initiated_by_id,
      job_id: "#{DateTime.utc_now()}-#{UUID.uuid4()}",
      job_type: job_type,
      configuration: config
    }
    {:ok, job}
  end

  defp preprocess(%DatasetJob{job_type: :custom} = job) do

    job = set_ignore_student_ids(job)

    chunk_size = Utils.determine_chunk_size(job.configuration.excluded_fields)
    config = %JobConfig{job.configuration | chunk_size: chunk_size}
    {:ok, %DatasetJob{job | configuration: config}}
  end

  defp preprocess(%DatasetJob{job_type: :datashop} = job) do

    job = set_ignore_student_ids(job)

    build_json_context(job)
    |> stage_json_context(job)
  end

  defp set_ignore_student_ids(%DatasetJob{configuration: config} = job) do
    ignored_student_ids = Utils.determine_ignored_student_ids(job.configuration.section_ids)
    config = %JobConfig{job.configuration | ignored_student_ids: ignored_student_ids}
    %DatasetJob{job | configuration: config}
  end

  defp build_json_context(%DatasetJob{project_id: project_id}) do
    result =
      Path.join(__DIR__, "/datasets/context.sql")
      |> File.read!()
      |> Repo.query([project_id, project_id, project_id, project_id])

    case result do
      {:ok, %Postgrex.Result{rows: rows}} ->
        {:ok , rows}

      e -> e
    end
  end

  defp stage_json_context({:error, e}, _), do: {:error, e}
  defp stage_json_context({:ok, context}, %DatasetJob{job_id: job_id} = job) do
    case Application.get_env(:oli, :emr_dataset_context_bucket)
    |> S3.put_object("contexts/#{job_id}.json", context, [])
    |> ExAws.request() do
      {:ok, _} -> {:ok, job}
      e -> e
    end
  end

  defp submit(%DatasetJob{} = job) do
    case determine_application_id() do
      {:ok, application_id} ->

        %DatasetJob{job | application_id: application_id}
        |> EmrServerless.submit_job()

      {:error, e} -> {:error, e}
    end
  end

  def determine_application_id() do

    case EmrServerless.list_applications() do

      {:ok, json} ->
         # Parse and find the appliction whose name matches the configured application name
         emr_application_name = Settings.emr_application_name()

         case Enum.filter(json["applications"], fn app -> app["name"] == emr_application_name end) do
           [app] -> {:ok, app["id"]}
           [] -> {:error, "Application not found"}
         end

      e -> e
    end
  end

  def update_job_statuses() do

    # Get the application and job run ids for all jobs that are not in a terminal state
    by_app_ids = fetch_app_job_ids()

    # For each application id, issue a request to the EMR serverless endpoint to get the job run statuses
    Enum.keys(by_app_ids)
    |> Enum.map(fn app_id -> EmrServerless.get_jobs(app_id) end)

    # Update the job status in the database

  end

  defp persist(job) do
    Repo.insert(job)
  end

  defp fetch_app_job_ids() do
    # Get the application and job run ids for all jobs that are not in a terminal state
    query = from(j in DatasetJob,
      where: j.status in [:submitted, :pending, :scheduled, :running, :cancelling, :queued],
      select: {j.application_id, j.job_run_id})

    Repo.all(query)
    |> Enum.group_by(&elem(&1, 0))

  end

end
