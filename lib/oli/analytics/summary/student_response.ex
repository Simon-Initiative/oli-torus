defmodule Oli.Analytics.Summary.StudentResponse do
  use Ecto.Schema
  import Ecto.Changeset

  schema "student_responses" do

    belongs_to(:section, Oli.Delivery.Sections.Section)
    belongs_to(:resource_part_response, Oli.Analytics.Summary.ResourcePartResponse)
    belongs_to(:page, Oli.Resources.Resource)
    belongs_to(:user, Oli.Accounts.User)

  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:section_id, :resource_part_response_id, :page_id, :user_id])
    |> validate_required([:section_id, :resource_part_response_id, :page_id, :user_id])
  end

end
