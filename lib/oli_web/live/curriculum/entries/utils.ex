defmodule OliWeb.Curriculum.Utils do
  alias Oli.Resources.ResourceType

  def is_container?(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id) == "container"
  end

  def resource_type_label(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id)
  end
end
