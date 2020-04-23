defmodule Oli.Resources.Page do

  alias Oli.Resources
  @type_id Oli.Resources.ResourceType.get_id_by_type("page")

  defstruct [
    :id,
    :resource_id,
    :resource_type_id,
    :title,
    :slug,
    :deleted,
    :author_id,
    :previous_revision_id,
    :content,
    :objectives,
    :graded,
    :inserted_at,
    :updated_at,
  ]

  def from_revision(%Oli.Resources.Revision{} = revision) do
    %Oli.Resources.Page{
      id: revision.id,
      resource_id: revision.resource_id,
      title: revision.title,
      resource_type_id: revision.resource_type_id,
      slug: revision.slug,
      deleted: revision.deleted,
      author_id: revision.author_id,
      previous_revision_id: revision.previous_revision_id,
      content: revision.content,
      objectives: Map.get(revision.objectives, revision.resource_id),
      graded: revision.graded,
      inserted_at: revision.inserted_at,
      updated_at: revision.updated_at
    }
  end


  def create_new(attrs) do

    {:ok, resource} = Resources.create_new_resource()

    with_type = Map.put(attrs, :resource_type_id, @type_id)
    {:ok, revision} = Resources.create_revision(with_type)

    {:ok, from_revision(revision)}

  end

end
