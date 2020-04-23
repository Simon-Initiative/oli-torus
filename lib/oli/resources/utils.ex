defmodule Oli.Resources.Utils do

  alias Oli.Resources.Revision
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Page
  alias Oli.Resources.Container
  alias Oli.Resources.Objective
  alias Oli.Resources.Activity

  def to_revision(wrapper) do
    Map.merge(%Oli.Resources.Revision{}, wrapper)
  end

  def to_wrapper(%Revision{resource_type_id: resource_type_id} = revision) do

    case ResourceType.get_type_by_id(resource_type_id) do
      :page -> Page.from_revision(revision)
      :container -> Container.from_revision(revision)
      :activity -> Activity.from_revision(revision)
      :objective -> Objective.from_revision(revision)
    end

  end

  def to_wrapper(revisions) when is_list(revisions) do
    Enum.map(revisions, &to_wrapper/1)
  end


end
