defmodule Oli.Resources.Revision do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  @derive {Jason.Encoder,
           only: [
             :content,
             :objectives,
             :tags,
             :slug,
             :deleted,
             :author_id,
             :previous_revision_id,
             :resource_type_id,
             :graded,
             :max_attempts,
             :time_limit,
             :scoring_strategy_id,
             :activity_type_id,
             :title,
             :resource_id,
             :intro_video,
             :poster_image,
             :intro_content,
             :duration_minutes,
             :id
           ]}
  schema "revisions" do
    #
    # NOTE: any field additions made here should be made also
    # in `Oli.Resources.create_revision_from_previous`
    #

    # fields that apply to all types
    field :title, :string
    field :slug, :string
    field :deleted, :boolean, default: false
    field :ids_added, :boolean, default: false
    belongs_to :author, Oli.Accounts.Author
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :previous_revision, Oli.Resources.Revision
    belongs_to :resource_type, Oli.Resources.ResourceType

    # fields that apply to only a subset of the types
    field :content, :map, default: %{}
    field :children, {:array, :id}, default: []
    field :tags, {:array, :id}, default: []
    field :objectives, :map, default: %{}
    field :graded, :boolean, default: false
    field :batch_scoring, :boolean, default: true
    field :replacement_strategy, Ecto.Enum, values: [:none, :selections, :dynamic, :both], default: :none
    field :duration_minutes, :integer, default: nil
    field :intro_content, :map, default: %{}
    field :intro_video, :string, default: nil
    field :poster_image, :string, default: nil
    field :full_progress_pct, :integer, default: 100

    # 0 represents "unlimited" attempts
    field :max_attempts, :integer, default: 0
    field :recommended_attempts, :integer, default: 0
    field :time_limit, :integer, default: 0

    field :scope, Ecto.Enum, values: [:embedded, :banked], default: :embedded
    field :retake_mode, Ecto.Enum, values: [:normal, :targeted], default: :normal

    field :assessment_mode, Ecto.Enum,
      values: [:traditional, :one_at_a_time],
      default: :traditional

    field :parameters, :map

    embeds_one :legacy, Oli.Resources.Legacy, on_replace: :delete
    embeds_one :explanation_strategy, Oli.Resources.ExplanationStrategy, on_replace: :delete

    embeds_one :collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig,
      on_replace: :delete

    belongs_to :scoring_strategy, Oli.Resources.ScoringStrategy
    belongs_to :activity_type, Oli.Activities.ActivityRegistration
    belongs_to :primary_resource, Oli.Resources.Resource

    has_many :warnings, Oli.Qa.Warning

    field(:total_count, :integer, virtual: true)
    field(:page_type, :string, virtual: true)
    field(:parent_slug, :string, virtual: true)
    field(:total_attempts, :integer, virtual: true)
    field(:avg_score, :float, virtual: true)

    field :purpose, Ecto.Enum,
      values: [:foundation, :application, :deliberate_practice],
      default: :foundation

    field :relates_to, {:array, :id}, default: []

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_revision, attrs \\ %{}) do
    resource_revision
    |> cast(attrs, [
      :title,
      :slug,
      :deleted,
      :ids_added,
      :author_id,
      :resource_id,
      :primary_resource_id,
      :previous_revision_id,
      :resource_type_id,
      :content,
      :children,
      :tags,
      :objectives,
      :graded,
      :batch_scoring,
      :replacement_strategy,
      :duration_minutes,
      :intro_content,
      :intro_video,
      :poster_image,
      :max_attempts,
      :recommended_attempts,
      :time_limit,
      :scope,
      :retake_mode,
      :assessment_mode,
      :parameters,
      :scoring_strategy_id,
      :activity_type_id,
      :purpose,
      :relates_to,
      :full_progress_pct
    ])
    |> cast_embed(:legacy)
    |> cast_embed(:explanation_strategy)
    |> cast_embed(:collab_space_config)
    |> validate_required([:title, :deleted, :author_id, :resource_id, :resource_type_id])
    |> Slug.update_on_change("revisions")
  end
end
