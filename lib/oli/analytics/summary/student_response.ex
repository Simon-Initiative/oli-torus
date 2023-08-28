defmodule Oli.Analytics.Summary.StudentResponse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "student_responses" do

    belongs_to(:section_response_summary_id, Oli.Analytics.Summary.SectionResponseSummary)
    belongs_to(:user, Oli.Accounts.User)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:section_response_summary_id, :user_id])
    |> validate_required([:section_response_summary_id, :user_id])
  end

end
