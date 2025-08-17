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

  def changeset(step, attrs) do
    # Normalize observation to always be a map
    attrs = normalize_observation(attrs)
    
    step
    |> cast(attrs, __schema__(:fields))
    |> validate_required([:run_id, :step_num, :phase])
  end
  
  defp normalize_observation(%{observation: obs} = attrs) when not is_map(obs) and not is_nil(obs) do
    # Wrap non-map, non-nil observations in a map
    normalized_obs = %{content: obs}
    Map.put(attrs, :observation, normalized_obs)
  end
  
  defp normalize_observation(%{observation: nil} = attrs) do
    # Convert nil to empty map
    Map.put(attrs, :observation, %{})
  end
  
  defp normalize_observation(attrs), do: attrs
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
  alias Oli.Repo
  import Ecto.Query
  import Ecto.Changeset
  require Logger

  @spec create_run(map) :: {:ok, Run.t()} | {:error, Ecto.Changeset.t()}
  def create_run(attrs) do
    attrs = Map.put_new(attrs, :started_at, DateTime.utc_now())
    
    %Run{}
    |> Run.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_run(Run.t() | String.t(), map) ::
          {:ok, Run.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_run(run_or_id, attrs) do
    case run_or_id do
      %Run{} = run ->
        run
        |> Run.changeset(attrs)
        |> Repo.update()

      id when is_binary(id) ->
        case Repo.get(Run, id) do
          nil -> {:error, :not_found}
          run -> update_run(run, attrs)
        end
    end
  end

  @spec get_run(String.t()) :: Run.t() | nil
  def get_run(id) do
    Repo.get(Run, id)
  end

  @spec append_step(map) :: {:ok, Step.t()} | {:error, Ecto.Changeset.t()}
  def append_step(attrs) do
    attrs = Map.put_new(attrs, :inserted_at, DateTime.utc_now())

    %Step{}
    |> Step.changeset(attrs)
    |> unique_constraint(:step_num, name: :agent_steps_pkey, message: "Step already exists for this run")
    |> Repo.insert()
  end

  @spec get_steps(String.t()) :: [Step.t()]
  def get_steps(run_id) do
    from(s in Step, where: s.run_id == ^run_id, order_by: s.step_num)
    |> Repo.all()
  end

  @spec create_draft(map) :: {:ok, Draft.t()} | {:error, Ecto.Changeset.t()}
  def create_draft(attrs) do
    %Draft{}
    |> Draft.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_drafts(String.t()) :: [Draft.t()]
  def list_drafts(run_id) do
    from(d in Draft, where: d.run_id == ^run_id, order_by: [desc: d.inserted_at])
    |> Repo.all()
  end

  @spec update_draft(String.t(), map) :: {:ok, Draft.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_draft(draft_id, attrs) do
    case Repo.get(Draft, draft_id) do
      nil -> {:error, :not_found}
      draft ->
        draft
        |> Draft.changeset(attrs)
        |> Repo.update()
    end
  end

  # Private helper functions
end
