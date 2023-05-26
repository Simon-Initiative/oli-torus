defmodule OliWeb.Curriculum.Utils do
  use Phoenix.HTML

  alias Oli.Resources.ResourceType

  def is_container?(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id) == "container"
  end

  def is_adaptive_page?(rev) do
    ResourceType.is_adaptive_page(rev)
  end

  def resource_type_label(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id)
  end
end
