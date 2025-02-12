defmodule OliWeb.OpenAndFreeView do
  use OliWeb, :view

  alias OliWeb.Common.Utils

  def get_path([:independent_learner | rest]),
    do: apply(Routes, :independent_sections_path, [OliWeb.Endpoint | rest])
end
