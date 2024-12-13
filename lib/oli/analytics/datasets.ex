defmodule Oli.Analytics.Datasets do

  alias Oli.Analytics.Datasets.JobConfig
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.Utils
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets.BrowseJobOptions
  alias Oli.Analytics.Datasets.EmrServerless
  alias Oli.Repo.{Paging, Sorting}
  alias ExAws.S3
  alias ExAws
  alias Oli.Repo
  import Ecto.Query
  require Logger

  @terminal_states [:success, :failed]


  @doc """
  Submits a new dataset creation job to the EMR serverless
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

  @doc """
  Browse jobs in the system, with optional filtering and sorting.  This function
  is used to display a list of jobs in the UI, and supports pagination, filtering by
  initiated_by_id, project_id, job_type, and status, and sorting by project_title and
  initiator_email.
  """
  def browse_jobs(
    %Paging{limit: limit, offset: offset},
    %Sorting{direction: direction, field: field},
    %BrowseJobOptions{} = options) do

    filter_by_initiated_by_id =
      if options.initiated_by_id,
        do: dynamic([j, _, _], j.initiated_by_id == ^options.initiated_by_id),
        else: true

    filter_by_project_id =
      if options.project_id,
        do: dynamic([j, _, _], j.project_id == ^options.project_id),
        else: true

    filter_by_job_type =
      if options.job_type,
        do: dynamic([j, _, _], j.job_type == ^options.job_type),
        else: true

    filter_by_statuses =
      case options.statuses do
        nil -> true
        [] -> true
        statuses -> dynamic([j, _, _], j.status in ^statuses)
      end

      query =
        DatasetJob
        |> join(:left, [j], u in Oli.Accounts.Author, on: j.initiated_by_id == u.id)
        |> join(:left, [j, _], proj in Oli.Authoring.Course.Project,
          on: j.project_id == proj.id
        )
        |> where(^filter_by_initiated_by_id)
        |> where(^filter_by_project_id)
        |> where(^filter_by_job_type)
        |> where(^filter_by_statuses)
        |> limit(^limit)
        |> offset(^offset)
        |> select_merge([_j, u, p], %{
          total_count: fragment("count(*) OVER()"),
          project_title: p.title,
          initiator_email: u.email
        })

      # sorting
      query =
        case field do
          :project_title ->
            order_by(query, [_, _, p], {^direction, p.title})

          :initiator_email ->
            order_by(query, [_, u, _], {^direction, u.email})

          _ ->
            order_by(query, [j, _, _], {^direction, field(j, ^field)})
        end

      # ensure there is always a stable sort order based on id, in addition to the specified sort order
      query = order_by(query, [j, _, _], j.id)

      Repo.all(query)

  end

  @doc """
  Returns the values for the project filter (the distinct set of projects that have
  jobs in the system)
  """
  def get_project_values() do
    query = DatasetJob
      |> join(:left, [j], proj in Oli.Authoring.Course.Project, on: j.project_id == proj.id)
      |> distinct(true)
      |> select([_j, proj], {proj.id, proj.title})

    Repo.all(query)
  end

  @doc """
  Returns the values for the initiator filter (the distinct set of initiators that have
  jobs in the system)
  """
  def get_initator_values(project_id \\ nil) do

    filter_by_project_id =
      if project_id,
        do: dynamic([j, _], j.project_id == ^project_id),
        else: true

    query = DatasetJob
    |> join(:left, [j], u in Oli.Accounts.Author, on: j.initiated_by_id == u.id)
    |> distinct(true)
    |> where(^filter_by_project_id)
    |> select([_j, u], {u.id, u.email})

    Repo.all(query)
  end

  @doc """
  Updates the status of all active jobs in the database by querying the EMR serverless
  environment and checking on their ground truth statuses.  This is multi step process:

  1. Fetch the application and job run ids from the DB for all jobs that are not in a terminal state,
  grouped by application id.

  2. Fetch the job statuses in bulk by using the application id from the EMR serverless environment.
  We also have to consider that over time the application id may change, so we need to fetch job
  statuses for more than one application id.

  3. We then determine which statuses have changed, and then issue a bulk update to the database.

  This function guarantees that we do 1 DB read and 1 DB write.  We cannot put an upper bound on the
  number of API calls to the EMR serverless environment, as this is dependent on the number of active
  jobs in the system (and the fact that we can only fetch 50 jobs statuses at a time) and the number
  of applications tied to these jobs.  We expect low volume of jobs, so this should result in a
  at most 1 or 2 API calls to the EMR serverless environment.

  This function returns {:ok, []} if there are no jobs to update, or {:ok, [{db_id, new_status}]}
  for all of the jobs that have been updated.

  ## Examples

      iex> Datasets.update_job_statuses()
      {:ok, []}

      iex> Datasets.update_job_statuses()
      {:ok, [{1, :success}, {2, :failed}]}
  """
  def update_job_statuses() do

    # Get the application and job run ids for all jobs that are not in a terminal state
    active_jobs_by_id = fetch_app_job_ids()

    statuses_by_id = Enum.map(active_jobs_by_id, fn {app_id, [earliest | _rest]} -> EmrServerless.get_jobs(app_id, earliest.inserted_at) end)
    |> Enum.reduce([], fn result, all ->
      case result do
        {:ok, jobs} -> jobs ++ all
        {:error, reason} ->
          Logger.warning("Failed to fetch job statuses: #{Kernel.to_string(reason)}")
          all
      end
    end)
    |> Enum.reduce(%{}, fn job, all -> Map.put(all, job["id"], job) end)

    # Pair up the jobs and their statuses, filtering to those whose have changed
    to_update = Enum.reduce(active_jobs_by_id, [], fn {_, jobs}, all -> jobs ++ all end)
    |> Enum.map(fn job -> {job, Map.get(statuses_by_id, job.job_run_id, nil)} end)
    |> Enum.filter(fn {job, status_job} -> status_job != nil and job.status != status_job["state"] |> from_emr_status() end)

    # Update the job status in the database
    case to_update do
      [] -> {:ok, []}
      _ ->
        case bulk_update_statuses(to_update) do
          {:ok, _} ->

            # we want to return back a list of {db_id, new_status} tuples
            to_update = Enum.map(to_update, fn {db_job, status_job} -> {db_job.id, status_job["state"] |> from_emr_status()} end)
            {:ok, to_update}
          e -> e
        end
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
    ignored_student_ids = Utils.determine_ignored_student_ids(config.section_ids)
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


  # Find the application id that matches the configured application name
  defp determine_application_id() do

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

  defp bulk_update_statuses(to_update) do
    {values, params, _} =
      Enum.reduce(to_update, {[], [], 0}, fn {_db_job, status_job}, {values, params, i} ->
        {
          values ++ ["($#{i + 1}, $#{i + 2})"],
          params ++ [status_job["state"] |> String.downcase(), status_job["id"]],
          i + 2
        }
      end)

      values = Enum.join(values, ",")

    sql = """
      UPDATE dataset_jobs
      SET
        status = batch_values.status,
        updated_at = NOW()
      FROM (
          VALUES
          #{values}
      ) AS batch_values (status, job_run_id)
      WHERE dataset_jobs.job_run_id = batch_values.job_run_id
    """

    Ecto.Adapters.SQL.query(Oli.Repo, sql, params)
  end

  defp from_emr_status(status_str) do
    String.downcase(status_str) |> String.to_existing_atom()
  end

  defp persist(job) do
    Repo.insert(job)
  end

  defp fetch_app_job_ids() do
    # Get the application and job run ids for all jobs that are not in a terminal state
    query = from(j in DatasetJob,
      where: j.status in [:submitted, :pending, :scheduled, :running, :cancelling, :queued])

    Repo.all(query)
    |> Enum.group_by(fn job -> job.application_id end)
    # now sort each DatasetJob struct  by earliest inserted_at
    |> Enum.map(fn {app_id, jobs} -> {app_id, Enum.sort_by(jobs, & &1.inserted_at)} end)

  end

end
