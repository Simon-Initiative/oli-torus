defmodule Oli.Rendering.Context do
  @moduledoc """
  The context struct that is used by the renderers contains useful
  data that may change the way rendering occurs.
  """
  defstruct user: nil,
            activity_map: %{},
            render_opts: %{
              render_errors: true
            },
            # Mode can be one of  [:delivery, :review, :author_preview, :instructor_preview]
            mode: :delivery,
            revision_slug: nil,
            section_slug: nil,
            project_slug: nil,
            activity_types_map: %{},
            group_id: nil,
            survey_id: nil,
            bib_app_params: [],
            submitted_surveys: %{}
end
