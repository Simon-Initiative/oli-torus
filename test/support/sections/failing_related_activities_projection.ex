defmodule Oli.Test.Sections.FailingRelatedActivitiesProjection do
  @moduledoc false

  def persist(_section, _opts \\ []), do: {:error, :forced_projection_failure}
end
