defmodule Oli.Interop.IngestState do
  defstruct [
    # Unzipped raw entries
    :entries,

    # The preprocessed state
    # ----------------------
    :resource_map,

    # The three well-known resources
    :project,
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
    :publication,
    :author,

    # Maps of legacy id to the revision for each resource type
    :tag_map,
    :bib_map,
    :objective_map,
    :page_map,
    :activity_map,
    :container_map,

    # List of all errors encountered
    # ------------------------------
    :errors,

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

  def steps() do
    [
      :unzip,
      :parse_json,
      :validate_idrefs,
      :migrate_content,
      :validate_activities,
      :validate_pages
    ]
  end

  def step_descriptors() do
    [
      {:unzip, "Unzipping archive"},
      {:parse_json, "Parsing and verifying JSON files"},
      {:validate_idrefs, "Validate cross file id references"},
      {:migrate_content, "Migrating content to latest versions"},
      {:validate_activities, "Validating Activity JSON"},
      {:validate_pages, "Validating Page JSON"}
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
