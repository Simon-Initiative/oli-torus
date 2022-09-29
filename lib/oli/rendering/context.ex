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
            page_id: nil,
            section_slug: nil,
            project_slug: nil,
            activity_types_map: %{},
            resource_attempt: nil,
            group_id: nil,
            survey_id: nil,
            pagination_mode: "normal",
            bib_app_params: [],
            submitted_surveys: %{},
            historical_attempts: nil,
            resource_summary_fn: nil
end
