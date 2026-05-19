defmodule Oli.InstructorDashboard.Recommendations.RecommendationInstance do
  @moduledoc """
  Persists each generated instructor-dashboard recommendation instance for a
  section and scoped dashboard container.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section

  @container_types [:course, :container]
  @generation_modes [:implicit, :explicit_regen]
  @states [:generating, :ready, :no_signal, :fallback, :expired]

  @type t :: %__MODULE__{
          id: integer() | nil,
          section_id: integer() | nil,
          section: Section.t() | Ecto.Association.NotLoaded.t() | nil,
          container_type: :course | :container | nil,
          container_id: integer() | nil,
          generation_mode: :implicit | :explicit_regen | nil,
          state: :generating | :ready | :no_signal | :fallback | :expired | nil,
          message: String.t() | nil,
          prompt_version: String.t() | nil,
          prompt_snapshot: map(),
          original_prompt: map(),
          response_metadata: map(),
          generated_by_user_id: integer() | nil,
          generated_by_user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  def container_types, do: @container_types
  def generation_modes, do: @generation_modes
  def states, do: @states

  schema "instructor_dashboard_recommendation_instances" do
    belongs_to :section, Section

    field :container_type, Ecto.Enum, values: @container_types
    field :container_id, :integer
    field :generation_mode, Ecto.Enum, values: @generation_modes
    field :state, Ecto.Enum, values: @states
    field :message, :string
    field :prompt_version, :string
    field :prompt_snapshot, :map, default: %{}
    field :original_prompt, :map, default: %{}
    field :response_metadata, :map, default: %{}

    belongs_to :generated_by_user, User, foreign_key: :generated_by_user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(recommendation_instance, attrs) do
    recommendation_instance
    |> cast(attrs, [
      :section_id,
      :container_type,
      :container_id,
      :generation_mode,
      :state,
      :message,
      :prompt_version,
      :prompt_snapshot,
      :original_prompt,
      :response_metadata,
      :generated_by_user_id
    ])
    |> validate_required([
      :section_id,
      :container_type,
      :generation_mode,
      :state,
      :prompt_version
    ])
    |> validate_message_requirement()
    |> assoc_constraint(:section)
    |> assoc_constraint(:generated_by_user)
    |> check_constraint(:container_id,
      name: :recommendation_instances_container_scope_check,
      message: "must match the selected container_type"
    )
  end

  defp validate_message_requirement(changeset) do
    case get_field(changeset, :state) do
      state when state in [:generating, :expired] ->
        changeset

      _other ->
        validate_required(changeset, [:message])
    end
  end
end
