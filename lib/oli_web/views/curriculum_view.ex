defmodule OliWeb.CurriculumView do
  use OliWeb, :view

  def page_type(resource) do
    type = Repo.preload(resource, :resource_type)
    # return prettified type
  end
end
