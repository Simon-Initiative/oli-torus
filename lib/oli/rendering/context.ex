defmodule Oli.Rendering.Context do
  @moduledoc """
  The context struct that is used by the renderers contains useful
  data that may change the way rendering occurs. It is intended to be read-only
  by the renderers
  """
  defstruct user: nil,
            activity_map: %{},
            render_opts: %{
              render_errors: true
            },
            # Mode can be one of  [:delivery, :review, :author_preview, :instructor_preview]
            mode: :delivery,
            revision_slug: nil,
            page_id: nil,
            section_slug: nil,
            project_slug: nil,
            activity_types_map: %{},
            resource_attempt: nil,
            bib_app_params: []
end
