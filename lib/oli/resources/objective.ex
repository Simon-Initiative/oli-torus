defmodule Oli.Resources.Objective do
  alias Oli.Resources
  @type_id Oli.Resources.ResourceType.get_id_by_type("objective")

  defstruct [
    :id,
    :resource_id,
    :resource_type_id,
    :title,
    :slug,
    :deleted,
    :author_id,
    :previous_revision_id,
    :children,
    :inserted_at,
    :updated_at
  ]

  def from_revision(%Oli.Resources.Revision{} = revision) do
    %Oli.Resources.Objective{
      id: revision.id,
      resource_id: revision.resource_id,
      title: revision.title,
      slug: revision.slug,
      resource_type_id: revision.resource_type_id,
      deleted: revision.deleted,
      author_id: revision.author_id,
      previous_revision_id: revision.previous_revision_id,
      children: revision.children,
      inserted_at: revision.inserted_at,
      updated_at: revision.updated_at
    }
  end

  def create_new(attrs) do
    {:ok, resource} = Resources.create_new_resource()

    with_type =
      Map.put(attrs, :resource_type_id, @type_id)
      |> Map.put(:resource_id, resource.id)

    {:ok, revision} = Resources.create_revision(with_type)

    {:ok, from_revision(revision)}
  end
end
