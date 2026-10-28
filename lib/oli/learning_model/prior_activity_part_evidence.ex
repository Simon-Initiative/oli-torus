defmodule Oli.LearningModel.PriorActivityPartEvidence do
  @moduledoc """
  Set-membership projection for activity parts a learner has encountered in a Section.

  The row is keyed by activity part rather than learning objective because one part
  may target several objectives; objective fan-out is derived by the application
  transaction from the exact activity Revision.
  """

  use Ecto.Schema

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Section
  alias Oli.Resources.Resource

  @primary_key false
  schema "prior_activity_part_evidence" do
    belongs_to(:section, Section, primary_key: true)
    belongs_to(:user, User, primary_key: true)
    belongs_to(:activity, Resource, primary_key: true)
    field(:part_id, :string, primary_key: true)

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
