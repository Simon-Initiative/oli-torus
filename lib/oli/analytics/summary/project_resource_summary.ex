defmodule Oli.Analytics.Summary.ProjectResourceSummary do
  use Ecto.Schema
  import Ecto.Changeset

  schema "project_resource_summary" do

    belongs_to(:project, Oli.Authoring.Course.Project)
    belongs_to(:publication, Oli.Publishing.Publications.Publication)
    belongs_to(:revision, Oli.Resources.Revision)

    belongs_to(:resource, Oli.Resources.Resource)
    belongs_to(:resource_type, Oli.Resources.ResourceType)
    field(:part_id, :string)

    field(:num_correct, :integer, default: 0)
    field(:num_attempts, :integer, default: 0)
    field(:num_hints, :integer, default: 0)
    field(:num_first_attempts, :integer, default: 0)
    field(:num_first_attempts_correct, :integer, default: 0)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:project_id, :publication_id, :revision_id, :resource_id, :resource_type_id, :part_id, :num_correct, :num_attempts, :num_hints, :num_first_attempts, :num_first_attempts_correct])
    |> validate_required([:project_id, :resource_id, :resource_type_id])
  end

end
