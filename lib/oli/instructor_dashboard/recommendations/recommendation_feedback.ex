defmodule Oli.InstructorDashboard.Recommendations.RecommendationFeedback do
  @moduledoc """
  Persists instructor feedback against a recommendation instance.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.InstructorDashboard.Recommendations.RecommendationInstance

  @feedback_types [:thumbs_up, :thumbs_down, :additional_text]

  @type t :: %__MODULE__{
          id: integer() | nil,
          recommendation_instance_id: integer() | nil,
          recommendation_instance:
            RecommendationInstance.t() | Ecto.Association.NotLoaded.t() | nil,
          user_id: integer() | nil,
          user: User.t() | Ecto.Association.NotLoaded.t() | nil,
          feedback_type: :thumbs_up | :thumbs_down | :additional_text | nil,
          feedback_text: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  def feedback_types, do: @feedback_types

  schema "instructor_dashboard_recommendation_feedback" do
    belongs_to :recommendation_instance, RecommendationInstance
    belongs_to :user, User

    field :feedback_type, Ecto.Enum, values: @feedback_types
    field :feedback_text, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(recommendation_feedback, attrs) do
    recommendation_feedback
    |> cast(attrs, [:recommendation_instance_id, :user_id, :feedback_type, :feedback_text])
    |> validate_required([:recommendation_instance_id, :user_id, :feedback_type])
    |> validate_feedback_text()
    |> assoc_constraint(:recommendation_instance)
    |> assoc_constraint(:user)
    |> unique_constraint([:recommendation_instance_id, :user_id],
      name: :recommendation_feedback_unique_sentiment_per_user_idx,
      message: "sentiment already submitted for this recommendation"
    )
  end

  defp validate_feedback_text(changeset) do
    case get_field(changeset, :feedback_type) do
      :additional_text ->
        validate_required(changeset, [:feedback_text])

      _ ->
        changeset
    end
  end
end
