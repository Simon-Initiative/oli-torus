defmodule Oli.Analytics.Summary.StudentResponse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "student_responses" do

    belongs_to(:response_summary_id, Oli.Analytics.Summary.ResponseSummary)
    belongs_to(:user, Oli.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:response_summary_id, :user_id])
    |> validate_required([:response_summary_id, :user_id])
  end

end
