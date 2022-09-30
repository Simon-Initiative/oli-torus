defmodule Oli.Rendering.Content.ResourceSummary do
  @moduledoc """
  Defines the struct that contains necessary resource data used by the content renderer.
  These ResourceSummary structs can be requested by the renderer via resource_summary_fn.
  which will return a summary for a given resource_id
  """

  @enforce_keys [
    :title,
    :slug
  ]
  defstruct [
    # title of the resource
    :title,
    # slug of the resource
    :slug
  ]
end
