defmodule Oli.Authoring.ProjectRepair do
  @moduledoc """
  Provides the non-web boundary for analyzing and repairing authoring projects.

  Analysis streams current Basic-page revisions from one project's unpublished
  working publication and returns compact, deterministic issue records. Both public
  functions authorize the actor before resolving any project content, normalize a
  project struct or slug back to current database state, require an unpublished
  working publication, and validate bounded processing options.

  Repair derives work from fresh analysis, protects participant resources with
  durable authoring locks, and commits each changed page independently so failures
  remain bounded and retryable.
  """

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.ProjectRepair.{Analysis, Instrumentation, Repair}
  alias Oli.Publishing

  @default_stream_max_rows 100
  @max_stream_rows 500
  @default_resolution_batch_size 500
  @max_resolution_batch_size 1_000
  @max_preview_issue_rows 5_000
  @max_preview_group_pages 500
  @test_only_option_keys if Mix.env() == :test, do: [:after_lock_acquisition], else: []
  @option_keys [
                 :stream_max_rows,
                 :resolution_batch_size,
                 :preview_issue_limit,
                 :preview_group_page_limit
               ] ++
                 @test_only_option_keys

  @typedoc "A persisted project or its slug."
  @type project_ref :: Project.t() | String.t()

  @typedoc "Bounded processing options shared by analysis and repair preparation."
  @type option ::
          {:stream_max_rows, pos_integer()}
          | {:resolution_batch_size, pos_integer()}
          | {:preview_issue_limit, pos_integer()}
          | {:preview_group_page_limit, pos_integer()}

  @typedoc "Errors normalized at the project repair context boundary."
  @type error ::
          :not_authorized
          | :project_not_found
          | :working_publication_not_found
          | {:invalid_page_content, pos_integer()}
          | {:invalid_options, term()}

  @doc """
  Analyzes the current unpublished Basic pages in an authoring project.

  The operation is strictly read-only. It streams page content long enough to
  classify the page and extract nested activity ids, then retains only compact
  relationship maps and display metadata. Missing activities are reported but are
  never removed, and top-level Adaptive pages are excluded from all issue maps.
  """
  @spec analyze_project(project_ref(), Author.t(), [option()]) ::
          {:ok, Oli.Authoring.ProjectRepair.Report.t()} | {:error, error()}
  def analyze_project(project_or_slug, actor, opts \\ []) do
    started_at = Instrumentation.start_time()

    case prepare(project_or_slug, actor, opts) do
      {:ok, prepared} ->
        result = Analysis.analyze(prepared.project, prepared.publication, prepared.options)

        # Successful preparation gives instrumentation trusted persisted identity
        # values. Raw caller slugs or hand-built actors are never logged.
        Instrumentation.record(
          :analysis,
          started_at,
          result,
          prepared.project,
          prepared.actor,
          instrumentation_options(prepared.options)
        )

      {:error, _reason} = error ->
        # Prepare failures intentionally emit no project or actor identity. This
        # preserves the authorization-first privacy boundary and keeps arbitrary
        # caller-supplied slugs out of logs and telemetry.
        Instrumentation.record(
          :analysis,
          started_at,
          error,
          nil,
          nil,
          instrumentation_options(opts)
        )
    end
  end

  @doc """
  Repairs every currently resolvable cross-page shared activity in a project.

  Repair derives its plan from fresh server-side analysis, locks every source
  activity and participant page, and revalidates the revision-bearing plan before
  writing. Missing references are report-only and Adaptive pages cannot enter the
  repair plan. Operation-level failures are returned in a structured
  `%Oli.Authoring.ProjectRepair.RepairResult{}` rather than raised to the caller.
  """
  @spec repair_project(project_ref(), Author.t(), [option()]) ::
          {:ok, Oli.Authoring.ProjectRepair.RepairResult.t()} | {:error, error()}
  def repair_project(project_or_slug, actor, opts \\ []) do
    started_at = Instrumentation.start_time()

    case prepare(project_or_slug, actor, opts) do
      {:ok, prepared} ->
        result =
          with {:ok, report} <-
                 Analysis.analyze(prepared.project, prepared.publication, prepared.options) do
            Repair.repair(
              prepared.project,
              prepared.publication,
              prepared.actor,
              prepared.options,
              report
            )
          end

        # The repair path may internally analyze several times for safety. The
        # public invocation emits one completion event/log based on the final result
        # so operators see one record per admin action rather than per internal pass.
        Instrumentation.record(
          :repair,
          started_at,
          result,
          prepared.project,
          prepared.actor,
          instrumentation_options(prepared.options)
        )

      {:error, _reason} = error ->
        Instrumentation.record(
          :repair,
          started_at,
          error,
          nil,
          nil,
          instrumentation_options(opts)
        )
    end
  end

  # Authorization intentionally runs first. Besides providing defense in depth for
  # future console or service callers, this ordering prevents an unauthorized actor
  # from using error differences to probe whether a project or publication exists.
  defp prepare(project_or_slug, actor, opts) do
    with {:ok, persisted_actor} <- authorize(actor),
         {:ok, normalized_opts} <- normalize_options(opts),
         {:ok, project} <- resolve_project(project_or_slug),
         {:ok, publication} <- resolve_working_publication(project) do
      {:ok,
       %{
         project: project,
         publication: publication,
         actor: persisted_actor,
         options: normalized_opts
       }}
    end
  end

  defp authorize(%Author{id: actor_id}) when is_integer(actor_id) do
    # Never trust role data carried by the caller's struct. An author may have
    # been demoted since the LiveView session was established, and non-web callers
    # can construct structs by hand. Reloading here makes the database's current
    # role assignment the authorization source of truth for every invocation.
    case Accounts.get_author(actor_id) do
      %Author{} = persisted_actor ->
        case Accounts.is_system_admin?(persisted_actor) do
          true -> {:ok, persisted_actor}
          false -> {:error, :not_authorized}
        end

      nil ->
        # A nonexistent account is indistinguishable from any other unauthorized
        # actor so this boundary does not disclose account lifecycle information.
        {:error, :not_authorized}
    end
  end

  defp authorize(_actor), do: {:error, :not_authorized}

  # A caller may hold an old or hand-built Project struct. Re-resolving by slug and
  # matching the id ensures all later work uses current persisted project state.
  defp resolve_project(%Project{id: id, slug: slug}) when is_integer(id) and is_binary(slug) do
    case Course.get_project_by_slug(slug) do
      %Project{id: ^id, status: :active} = project -> {:ok, project}
      _other -> {:error, :project_not_found}
    end
  end

  defp resolve_project(slug) when is_binary(slug) do
    case Course.get_project_by_slug(slug) do
      %Project{status: :active} = project -> {:ok, project}
      _other -> {:error, :project_not_found}
    end
  end

  defp resolve_project(_project_or_slug), do: {:error, :project_not_found}

  # AuthoringResolver and every later write must be scoped to this unpublished
  # publication. Failing here prevents accidental fallback to a published snapshot.
  defp resolve_working_publication(%Project{slug: project_slug}) do
    case Publishing.project_working_publication(project_slug) do
      nil -> {:error, :working_publication_not_found}
      publication -> {:ok, publication}
    end
  end

  # Batch sizes are internal tuning controls rather than user input. Strictly
  # validating a small allowlist keeps tests configurable without creating an
  # unbounded or surprising execution mode for future callers.
  defp normalize_options(opts) when is_list(opts) do
    with true <- Keyword.keyword?(opts),
         :ok <- reject_unknown_options(opts),
         {:ok, stream_max_rows} <-
           bounded_positive_option(
             opts,
             :stream_max_rows,
             @default_stream_max_rows,
             @max_stream_rows
           ),
         {:ok, resolution_batch_size} <-
           bounded_positive_option(
             opts,
             :resolution_batch_size,
             @default_resolution_batch_size,
             @max_resolution_batch_size
           ),
         {:ok, preview_issue_limit} <-
           optional_bounded_positive_option(opts, :preview_issue_limit, @max_preview_issue_rows),
         {:ok, preview_group_page_limit} <-
           optional_bounded_positive_option(
             opts,
             :preview_group_page_limit,
             @max_preview_group_pages
           ),
         {:ok, after_lock_acquisition} <- test_only_lock_hook_option(opts) do
      {:ok,
       %{
         stream_max_rows: stream_max_rows,
         resolution_batch_size: resolution_batch_size,
         preview_issue_limit: preview_issue_limit,
         preview_group_page_limit: preview_group_page_limit,
         after_lock_acquisition: after_lock_acquisition
       }}
    else
      false -> {:error, {:invalid_options, :expected_keyword_list}}
      {:error, _reason} = error -> error
    end
  end

  defp normalize_options(_opts), do: {:error, {:invalid_options, :expected_keyword_list}}

  defp reject_unknown_options(opts) do
    case Keyword.keys(opts) -- @option_keys do
      [] -> :ok
      unknown -> {:error, {:invalid_options, {:unknown_options, Enum.uniq(unknown)}}}
    end
  end

  # Explicit ceilings are as important as positive lower bounds. These options
  # will directly control database cursor and resolver query sizes in Phase 2, so
  # accepting an arbitrary integer would defeat the bounded-memory guarantee.
  defp bounded_positive_option(opts, key, default, maximum) do
    case Keyword.get(opts, key, default) do
      value when is_integer(value) and value > 0 and value <= maximum ->
        {:ok, value}

      _value ->
        {:error, {:invalid_options, {:expected_integer_between, key, 1, maximum}}}
    end
  end

  defp optional_bounded_positive_option(opts, key, maximum) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_integer(value) and value > 0 and value <= maximum ->
        {:ok, value}

      {:ok, _value} ->
        {:error, {:invalid_options, {:expected_integer_between, key, 1, maximum}}}

      :error ->
        {:ok, nil}
    end
  end

  if Mix.env() == :test do
    # This hook exists only to prove the Phase 3 stale-fingerprint gate. It is not
    # part of the production option allowlist because arbitrary callbacks do not
    # belong in a safety-critical repair API.
    defp test_only_lock_hook_option(opts) do
      case Keyword.get(opts, :after_lock_acquisition) do
        nil -> {:ok, nil}
        hook when is_function(hook, 0) -> {:ok, hook}
        _other -> {:error, {:invalid_options, {:expected_function, :after_lock_acquisition, 0}}}
      end
    end
  else
    defp test_only_lock_hook_option(_opts), do: {:ok, nil}
  end

  defp instrumentation_options(%{
         stream_max_rows: stream_max_rows,
         resolution_batch_size: resolution_batch_size
       }) do
    %{
      stream_max_rows: stream_max_rows,
      resolution_batch_size: resolution_batch_size
    }
  end

  defp instrumentation_options(opts) when is_list(opts) do
    %{
      stream_max_rows: Keyword.get(opts, :stream_max_rows, @default_stream_max_rows),
      resolution_batch_size:
        Keyword.get(opts, :resolution_batch_size, @default_resolution_batch_size)
    }
  end

  defp instrumentation_options(_opts) do
    %{
      stream_max_rows: @default_stream_max_rows,
      resolution_batch_size: @default_resolution_batch_size
    }
  end
end
