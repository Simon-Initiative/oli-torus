defmodule Oli.Interop.Ingest.State do
  defstruct [
    # Unzipped raw entries
    :entries,

    # The preprocessed state
    # ----------------------
    :resource_map,

    # The three well-known resources
    :project_details,
    :media_manifest,
    :hierarchy,

    # Lists of id. resource JSON tuples partitioned by type
    :tags,
    :bib_entries,
    :activities,
    :objectives,
    :pages,
    :products,

    # The processed state
    # -------------------
    :project,
    :publication,
    :root_revision,
    :author,
    :slug_prefix,
    :resource_id_pool,
    :legacy_to_resource_id_map,
    :container_id_map,
    :registration_by_subtype,

    # List of all errors encountered
    # ------------------------------
    :errors,
    :force_rollback,

    # Progress notification functions
    # -------------------------------
    :notify_step_start,
    :notify_step_progress
  ]

  def new() do
    %__MODULE__{
      errors: [],
      entries: nil,
      resource_map: nil,
      tags: [],
      bib_entries: [],
      activities: [],
      objectives: [],
      pages: [],
      products: []
    }
  end

  def step_descriptors() do
    [
      # Unip
      {:unzip, "Unzipping archive"},
      # Preprocessing steps
      {:parse_json, "Parsing and verifying JSON files"},
      {:validate_idrefs, "Validate cross file id references"},
      {:migrate_content, "Migrating content to latest versions"},
      {:validate_activities, "Validating Activity JSON"},
      {:validate_pages, "Validating Page JSON"},
      # Processing steps
      {:project, "Creating project records"},
      {:bulk_allocate, "Bulk allocating all project resource records"},
      {:tags, "Creating tag records"},
      {:objectives, "Creating objective records"},
      {:bib_entries, "Creating bibliography records"},
      {:activities, "Creating activity records"},
      {:pages, "Creating page records"},
      {:hierarchy, "Creating root hierarchy records"},
      {:products, "Creating products"},
      {:publish_resources, "Creating all published resources"},
      {:hyperlinks, "Rewriting internal page to page hyperlinks"},
      {:media_items, "Creating media item records"}
    ]
  end

  def notify_step_start(state, step, num_tasks_fn \\ 0)

  def notify_step_start(%__MODULE__{notify_step_start: nil} = state, _, _), do: state

  def notify_step_start(%__MODULE__{notify_step_start: start_fn} = state, step, num_tasks_fn) do
    num_tasks =
      case num_tasks_fn do
        f when is_function(f) -> f.(state)
        n when is_number(n) -> n
      end

    start_fn.(step, num_tasks)
    state
  end

  def notify_step_progress(%__MODULE__{notify_step_progress: nil} = state, _), do: state

  def notify_step_progress(
        %__MODULE__{notify_step_progress: progress_fn} = state,
        task_detail
      ) do
    progress_fn.(task_detail)
    state
  end
end
