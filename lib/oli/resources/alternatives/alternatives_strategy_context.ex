defmodule Oli.Resources.Alternatives.AlternativesStrategyContext do
  @moduledoc """
  Context information that is required to execute alternatives strategies
  """
  defstruct user: nil,
            section_slug: nil,
            # mode set from the render context
            # e.g. :delivery, :review, :author_preview, :instructor_preview
            mode: nil
end
