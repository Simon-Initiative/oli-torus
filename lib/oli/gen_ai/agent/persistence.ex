defmodule Oli.GenAI.Agent.Schema.Run do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder,
           only: [
             :id,
             :goal,
             :run_type,
             :status,
             :plan,
             :context_summary,
             :budgets,
             :model,
             :cost_cents,
             :tokens_in,
             :tokens_out,
             :inserted_at,
             :updated_at
           ]}
  schema "agent_runs" do
    field :user_id, :id
    field :project_id, :id
    field :section_id, :id
    field :goal, :string
    field :run_type, :string
    field :status, :string, default: "running"
    field :plan, :map
    field :context_summary, :string
    field :budgets, :map
    field :model, :string
    field :cost_cents, :integer, default: 0
    field :tokens_in, :integer, default: 0
    field :tokens_out, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:goal, :run_type, :status])
  end
end

defmodule Oli.GenAI.Agent.Schema.Step do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "agent_steps" do
    field :run_id, :binary_id, primary_key: true
    field :step_num, :integer, primary_key: true
    field :phase, :string
    field :action, :map
    field :observation, :map
    field :rationale_summary, :string
    field :tokens_in, :integer
    field :tokens_out, :integer
    field :latency_ms, :integer
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(step, attrs),
    do:
      step |> cast(attrs, __schema__(:fields)) |> validate_required([:run_id, :step_num, :phase])
end

defmodule Oli.GenAI.Agent.Schema.Draft do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @statuses ~w(pending accepted rejected)a

  schema "agent_drafts" do
    field :run_id, :binary_id
    field :object_type, :string
    field :object_ref, :string
    field :patch, :map
    field :preview_html, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :metadata, :map
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:run_id, :object_type, :object_ref, :patch])
  end
end

defmodule Oli.GenAI.Agent.Persistence do
  @moduledoc "Context: durable storage for runs/steps/drafts."
  alias Oli.GenAI.Agent.Schema.{Run, Step, Draft}
  require Logger

  @spec create_run(map) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create_run(attrs) do
    # For now, just return success with the attrs as a mock run
    run = struct(Run, Map.put(attrs, :id, attrs[:id] || Ecto.UUID.generate()))
    Logger.debug("Mock: Created run #{run.id}")
    {:ok, run}
  end

  @spec update_run(Run.t() | String.t(), map) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t() | term}
  def update_run(run_or_id, attrs) do
    id =
      case run_or_id do
        %Run{id: id} -> id
        id when is_binary(id) -> id
      end

    Logger.debug("Mock: Updated run #{id} with #{inspect(attrs)}")
    {:ok, struct(Run, Map.put(attrs, :id, id))}
  end

  @spec append_step(map) :: {:ok, Step.t()} | {:error, Ecto.Changeset.t()}
  def append_step(attrs) do
    step = struct(Step, attrs)
    Logger.debug("Mock: Appended step #{attrs[:step_num]} for run #{attrs[:run_id]}")
    {:ok, step}
  end

  @spec create_draft(map) :: {:ok, Draft.t()} | {:error, Ecto.Changeset.t()}
  def create_draft(attrs) do
    draft = struct(Draft, Map.put(attrs, :id, Ecto.UUID.generate()))
    Logger.debug("Mock: Created draft #{draft.id}")
    {:ok, draft}
  end

  @spec list_drafts(String.t()) :: [Draft.t()]
  def list_drafts(run_id) do
    Logger.debug("Mock: Listed drafts for run #{run_id}")
    []
  end
end
