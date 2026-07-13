defmodule Oli.Resources.Alternatives.AlternativesStrategyContext do
  @moduledoc """
  Context information that is required to execute alternatives strategies
  """
  defstruct enrollment_id: nil,
            user: nil,
            institution_id: nil,
            project_id: nil,
            publication_id: nil,
            section_id: nil,
            section_slug: nil,
            project_slug: nil,
            activity_resource_ids: [],
            # mode set from the render context
            # e.g. :delivery, :review, :author_preview, :instructor_preview
            mode: nil,

            # map of resource ids to alternative details
            alternative_groups_by_id: nil
end
