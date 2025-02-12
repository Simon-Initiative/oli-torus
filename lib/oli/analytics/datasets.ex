defmodule Oli.Analytics.Datasets do
  @moduledoc """
  Provides functionality for creating and managing dataset creation jobs
  in the system. This module provides a single, high level API encapsulating
  both the internal and external operations required for the dataset job lifecycle.

  The external operations are provided through the AWS EMR serverless environment, but
  it is intentional to hide all aspects of that environment from the caller, so that
  it can be swapped out for a different provider or implementation in the future.

  The primary operations and the functions that are exposed are:

  * `create_job/4` - Submits a new dataset creation job
  * `update_job_statuses/0` - Updates the status of all active jobs in the system
  * `browse_jobs/3` - Browse jobs in the system, with optional filtering and sorting
  * `send_notification_emails/2` - Sends notification emails to the users who initiated the jobs

  The creation of dataset job results in a %DatasetJob{} record being persisted to the
  database and the job being submitted to the EMR serverless environment.  The remote EMR
  environment is polled periodically by `update_job_statuses/0`, which updates the status of
  all active jobs in the system.  When a job reaches a terminal state, the users who initiated
  the job are notified by email.

  Jobs can be browsed in the UI using `browse_jobs/3`, which supports pagination, filtering
  and sorting by project, initiator, job type, and status.  The results are returned as a list of
  %DatasetJob{} records, which can be used to display a list of jobs in the UI - particularly in
  tabular form.

  Jobs executing in the current EMR serverless environment generate and store result files
  in an S3 bucket.  These result sets typically are comprised of several files.  A manifest file
  in JSON format is generated for each job, which contains metadata about the job and the URL locations
  of all of the result files. This manifest file can be fetched from S3 and decoded into a map
  by `fetch_manifest/1`.

  """

  require Logger

  alias Oli.Analytics.Datasets.JobConfig
  alias Oli.Analytics.Datasets.DatasetJob
  alias Oli.Analytics.Datasets.Utils
  alias Oli.Analytics.Datasets.Settings
  alias Oli.Analytics.Datasets.BrowseJobOptions
  alias Oli.Analytics.Datasets.EmrServerless

  alias Oli.{Email, Mailer}

  alias Oli.Repo.{Paging, Sorting}
  alias ExAws.S3
  alias ExAws
  alias Oli.Repo
  import Ecto.Query
  require Logger

  @terminal_emr_states ["SUCCESS", "FAILED", "CANCELLED"]
  @terminal_states [:success, :failed, :cancelled]

  @doc """
  Retrieves a job by its id ensuring that it belongs to the asserted
  project.  If the job does not exist, or does not belong to the project,
  we return nil.
  """
  def get_job(id, project_slug) do
    query =
      from(j in DatasetJob,
        join: p in Oli.Authoring.Course.Project,
        on: j.project_id == p.id,
        join: u in Oli.Accounts.Author,
        on: j.initiated_by_id == u.id,
        where: j.id == ^id and p.slug == ^project_slug,
        select_merge: %{
          project_title: p.title,
          project_slug: p.slug,
          initiator_email: u.email
        }
      )

    Repo.one(query)
  end

  @doc """
  For a succesfully completed job, fetches the JSON manifest file from S3
  and decodes it into a map.
  """
  def fetch_manifest(%DatasetJob{job_id: job_id, status: :success}) do
    file_path = "#{job_id}/manifest.json"

    Logger.info("Fetching manifest for job #{job_id}")

    case S3.get_object(Settings.context_bucket(), file_path)
         |> ExAws.request() do
      {:ok, result} ->
        Logger.debug("Manifest fetched for job #{job_id}")
        {:ok, Poison.decode!(result.body)}

      {:error, e} ->
        Logger.error("Failed to fetch manifest for job #{job_id}: #{Kernel.to_string(e)}")
        {:error, e}
    end
  end

  @doc """
  Submits a new dataset creation job to the EMR serverless
  environment for processing.  This is a four step process:

  1. Initialize the job with the provided configuration, generating a unique job ID
  2. Preprocess the job configuration, depending on the job type
  3. Stage the lookup data in S3 for the job
  4. Submit the job to the EMR serverless environment
  5. Persist the job to the database

  Any of steps 2-5 can fail, in which case the job will not be persisted to the database
  and an error will be returned.  The error will be logged to the console. If the job
  submission fails in step 4, it is okay that the context had been successfully
  staged in step 3, as the staging is done in a way that is idempotent for job ids, but more
  importantly, retries of the entire job creation process results in a new context
  being staged in S3 for a new job id.

  ## Examples

      iex> Datasets.create_job(:datashop, 1, 2, %JobConfig{chunk_size: 10_000})
      {:ok, %DatasetJob{...}}

      iex> Datasets.create_job(:custom, 1, 2, %JobConfig{excluded_fields: [:response]})
      {:ok, %DatasetJob{...}}
  """
  def create_job(job_type, project_id, initiated_by_id, %JobConfig{} = config) do
    Logger.info("Dataset job creation initiated for project #{project_id}, job type #{job_type}")

    with {:ok, job} <- init(job_type, project_id, initiated_by_id, config),
         {:ok, job} <- preprocess(job),
         {:ok, job} <- stage_lookup_data(job),
         {:ok, job} <- submit(job),
         {:ok, job} <- persist(job) do
      Logger.info(
        "Dataset job successfully created for project #{project_id}, job id #{job.job_id}"
      )

      {:ok, job}
    else
      {:error, e} ->
        Logger.error("Failed to create dataset job #{Kernel.to_string(e)}")
        e
    end
  end

  def is_terminal_state?(status) do
    status in @terminal_states
  end

  @doc """
  Sends notification emails to the users who initiated the jobs, and any additional
  emails that have been specified in the job configuration.  The notification email
  contains a link to the job details page, where the user can view the status of the
  job and download the results.
  """
  def send_notification_emails(to_notify, url_builder_fn) do
    Logger.info("Sending notification emails for #{Enum.count(to_notify)} jobs")

    # Get the database ids of the jobs to notify
    {job_ids, _new_status} = Enum.unzip(to_notify)

    jobs =
      from(j in DatasetJob,
        join: u in Oli.Accounts.Author,
        on: j.initiated_by_id == u.id,
        join: p in Oli.Authoring.Course.Project,
        on: j.project_id == p.id,
        where: j.id in ^job_ids,
        select: %{
          id: j.id,
          job_id: j.job_id,
          email: u.email,
          project_slug: p.slug,
          notify_emails: j.notify_emails
        }
      )
      |> Repo.all()
      |> Enum.reduce(%{}, fn job, all -> Map.put(all, job.id, job) end)

    Enum.each(to_notify, fn {job_id, _new_status} ->
      job = Map.get(jobs, job_id)

      case job do
        nil ->
          Logger.error("Job #{job_id} not found")

        _ ->
          emails = job.notify_emails ++ [job.email]

          Enum.each(emails, fn email ->
            # Send the notification email
            Logger.debug(
              "Sending dataset notification email to #{email} for job id #{job.job_id}"
            )

            deliver_completion_email(email, url_builder_fn.(job.project_slug, job.id))
          end)
      end
    end)
  end

  defp send_email(email, subject, view, assigns) do
    Email.create_email(
      email,
      subject,
      view,
      assigns
    )
    |> Mailer.deliver_later()
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_completion_email(email, url) do
    send_email(
      email,
      "Dataset job completion",
      :dataset,
      %{
        url: url
      }
    )
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
        %BrowseJobOptions{} = options
      ) do
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
      |> join(:left, [j, _], proj in Oli.Authoring.Course.Project, on: j.project_id == proj.id)
      |> where(^filter_by_initiated_by_id)
      |> where(^filter_by_project_id)
      |> where(^filter_by_job_type)
      |> where(^filter_by_statuses)
      |> limit(^limit)
      |> offset(^offset)
      |> select_merge([_j, u, p], %{
        total_count: fragment("count(*) OVER()"),
        project_title: p.title,
        project_slug: p.slug,
        initiator_email: u.email
      })

    # sorting
    query =
      case field do
        :project_title ->
          order_by(query, [_, _, p], {^direction, p.title})

        :project_slug ->
          order_by(query, [_, _, p], {^direction, p.slug})

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
  Returns true if the user has at least one active job being tracked
  in the system, false otherwise.
  """
  def has_active_job?(user_id, project_id) do
    terminal_states =
      @terminal_emr_states
      |> Enum.map(fn status -> String.downcase(status) end)

    DatasetJob
    |> where(
      [j],
      j.project_id == ^project_id and j.initiated_by_id == ^user_id and
        j.status not in ^terminal_states
    )
    |> Repo.exists?()
  end

  @doc """
  Returns the values for the project filter (the distinct set of projects that have
  jobs in the system)
  """
  def get_project_values() do
    query =
      DatasetJob
      |> join(:left, [j], proj in Oli.Authoring.Course.Project, on: j.project_id == proj.id)
      |> distinct(true)
      |> select([_j, proj], %{id: proj.id, title: proj.title})

    Repo.all(query)
  end

  @doc """
  Returns the values for the initiator filter (the distinct set of initiators that have
  jobs in the system)
  """
  def get_initiator_values(project_id \\ nil) do
    filter_by_project_id =
      if project_id,
        do: dynamic([j, _], j.project_id == ^project_id),
        else: true

    query =
      DatasetJob
      |> join(:left, [j], u in Oli.Accounts.Author, on: j.initiated_by_id == u.id)
      |> distinct(true)
      |> where(^filter_by_project_id)
      |> select([_j, u], %{id: u.id, email: u.email})

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

    Logger.debug("Fetched #{Enum.count(active_jobs_by_id)} active jobs from DB")

    Enum.each(active_jobs_by_id, fn {_app_id, jobs} ->
      Enum.each(jobs, fn job ->
        Logger.debug("Job #{job.job_id} is run_id #{job.job_run_id} is #{job.status}")
      end)
    end)

    statuses_by_id =
      Enum.map(active_jobs_by_id, fn {app_id, [earliest | _rest]} ->
        twelve_hours_earlier = DateTime.add(earliest.inserted_at, -12, :hour)
        EmrServerless.get_jobs(app_id, twelve_hours_earlier)
      end)
      |> Enum.reduce([], fn result, all ->
        case result do
          {:ok, jobs} ->
            jobs ++ all

          {:error, reason} ->
            Logger.warning("Failed to fetch job statuses: #{Kernel.to_string(reason)}")
            all
        end
      end)
      |> Enum.reduce(%{}, fn job, all -> Map.put(all, job["id"], job) end)

    Logger.debug("Fetched #{Enum.count(statuses_by_id)} job statuses from EMR")

    Enum.each(statuses_by_id, fn {job_id, status} ->
      Logger.debug("Job #{job_id} is [#{Jason.encode!(status)}]")
    end)

    # Pair up the jobs and their statuses, filtering to those whose have changed
    to_update =
      Enum.reduce(active_jobs_by_id, [], fn {_, jobs}, all -> jobs ++ all end)
      |> Enum.map(fn job -> {job, Map.get(statuses_by_id, job.job_run_id, nil)} end)
      |> Enum.filter(fn {job, status_job} ->
        status_job != nil and job.status != status_job["state"] |> from_emr_status()
      end)

    # Update the job status in the database
    case to_update do
      [] ->
        {:ok, []}

      _ ->
        case bulk_update_statuses(to_update) do
          {:ok, _} ->
            # we want to return back a list of {db_id, new_status} tuples
            to_update =
              Enum.map(to_update, fn {db_job, status_job} ->
                {db_job.id, status_job["state"] |> from_emr_status()}
              end)

            {:ok, to_update}

          e ->
            e
        end
    end
  end

  @doc """
  Fetches the required survey ids for a given set of section ids.  This is used to determine
  which surveys are required for a given set of sections, so that we can generate the required
  survey dataset.
  """
  def fetch_required_survey_ids(section_ids) do
    query =
      Oli.Delivery.Sections.Section
      |> where([s], s.id in ^section_ids and not is_nil(s.required_survey_resource_id))
      |> distinct(true)
      |> select([s], s.required_survey_resource_id)

    Repo.all(query)
  end

  defp init(job_type, project_id, initiated_by_id, %JobConfig{} = config) do
    # The job_id will be a combination of the current timestamp and a UUID,
    # to ensure uniqueness across all jobs and ALL servers.  The timestamp is
    # is here to make it easier to identify the job in the AWS console (in the
    # S3 bucket directory)
    #
    # We also must comply with AWS naming conventions for EMR client tokens, which
    # must be alphanumeric and cannot contain spaces or colons.
    readable_timestamp =
      String.replace("#{DateTime.utc_now()}", " ", "_")
      |> String.replace(":", "-")

    job = %DatasetJob{
      project_id: project_id,
      initiated_by_id: initiated_by_id,
      job_id: "#{readable_timestamp}-#{UUID.uuid4()}",
      job_type: job_type,
      configuration: config
    }

    Logger.debug("Initialized dataset job #{job.job_id}")

    {:ok, job}
  end

  defp preprocess(%DatasetJob{job_type: :custom} = job) do
    job = set_ignore_student_ids(job)

    chunk_size = Utils.determine_chunk_size(job.configuration.excluded_fields)
    config = %JobConfig{job.configuration | chunk_size: chunk_size}

    Logger.debug("Preprocessed dataset job #{job.job_id}")

    {:ok, %DatasetJob{job | configuration: config}}
  end

  defp preprocess(%DatasetJob{job_type: :datashop} = job) do
    job = set_ignore_student_ids(job)

    Logger.debug("Preprocessed dataset job #{job.job_id}")

    {:ok, job}
  end

  defp stage_lookup_data(%DatasetJob{job_type: :datashop} = job) do
    Logger.debug("Staging lookup data for dataset job #{job.job_id}")

    build_json_context(job)
    |> stage_json_context(job)
  end

  defp set_ignore_student_ids(%DatasetJob{configuration: config} = job) do
    ignored_student_ids = Utils.determine_ignored_student_ids(config.section_ids)
    config = %JobConfig{job.configuration | ignored_student_ids: ignored_student_ids}
    %DatasetJob{job | configuration: config}
  end

  defp build_json_context(%DatasetJob{project_id: project_id, configuration: config}) do
    result =
      Oli.Analytics.Datasets.Utils.context_sql()
      |> Repo.query([config.section_ids, project_id, project_id, project_id, project_id])

    case result do
      {:ok, %Postgrex.Result{rows: [[context]]}} ->
        {:ok, context}

      e ->
        e
    end
  end

  defp stage_json_context({:error, e}, _), do: {:error, e}

  defp stage_json_context({:ok, context}, %DatasetJob{job_id: job_id} = job) do
    context_as_str = Poison.encode!(context)

    case S3.put_object(Settings.context_bucket(), "contexts/#{job_id}.json", context_as_str, [])
         |> ExAws.request() do
      {:ok, _} -> {:ok, job}
      e -> e
    end
  end

  defp submit(%DatasetJob{} = job) do
    Logger.debug("About to submit job #{job.job_id}")

    case determine_application_id() do
      {:ok, application_id} ->
        Logger.debug("Submitting job #{job.job_id} to application #{application_id}")

        %DatasetJob{job | application_id: application_id}
        |> EmrServerless.submit_job()

      {:error, e} ->
        Logger.error("Failed to submit job #{job.job_id}: #{Kernel.to_string(e)}")
        {:error, e}
    end
  end

  # Find the application id that matches the configured application name
  defp determine_application_id() do
    case EmrServerless.list_applications() do
      {:ok, json} ->
        # Parse and find the appliction whose name matches the configured application name
        emr_application_name = Settings.emr_application_name()

        case Enum.filter(json["applications"], fn app -> app["name"] == emr_application_name end) do
          [app] ->
            {:ok, app["id"]}

          [] ->
            Logger.warning("Dataset application not found: #{emr_application_name}")
            {:error, "Application not found"}
        end

      e ->
        Logger.error("Failed to list applications: #{Kernel.to_string(e)}")
        e
    end
  end

  # Updates the status of a collection of jobs whose statuses have changed, based on
  # the statuses fetched from the EMR serverless environment.  Conditionally, when
  # the status changes to a terminal state, the finished_on field is updated.
  defp bulk_update_statuses(to_update) do
    {values, params, _} =
      Enum.reduce(to_update, {[], [], 0}, fn {_db_job, status_job}, {values, params, i} ->
        {
          values ++ ["($#{i + 1}, $#{i + 2}::timestamp, $#{i + 3})"],
          params ++
            [
              status_job["state"] |> String.downcase(),
              if status_job["state"] in @terminal_emr_states do
                DateTime.utc_now()
              else
                nil
              end,
              status_job["id"]
            ],
          i + 3
        }
      end)

    values = Enum.join(values, ",")

    sql = """
      UPDATE dataset_jobs
      SET
        status = batch_values.status,
        finished_on = batch_values.finished_on,
        updated_at = NOW()
      FROM (
          VALUES
          #{values}
      ) AS batch_values (status, finished_on, job_run_id)
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
    query =
      from(j in DatasetJob,
        where: j.status in [:submitted, :pending, :scheduled, :running, :cancelling, :queued]
      )

    Repo.all(query)
    |> Enum.group_by(fn job -> job.application_id end)
    # now sort each DatasetJob struct  by earliest inserted_at
    |> Enum.map(fn {app_id, jobs} -> {app_id, Enum.sort_by(jobs, & &1.inserted_at)} end)
  end
end
