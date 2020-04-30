defmodule Oli.Delivery.Learning.Feedback do
  use Ecto.Schema
  import Ecto.Changeset

  schema "feedbacks" do
    field :assigned_by, :string
    field :body, :map

    belongs_to :response, Oli.Delivery.Learning.Response
    belongs_to :activity_access, Oli.Delivery.Learning.ActivityAccess

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(feedback, attrs) do
    feedback
    |> cast(attrs, [:assigned_by, :body, :response_id, :activity_access_id])
    |> validate_required([:assigned_by, :body])
  end
end
