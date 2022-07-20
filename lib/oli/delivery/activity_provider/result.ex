defmodule Oli.Delivery.ActivityProvider.Result do
  defstruct [
    :errors,
    :revisions,
    :bib_revisions,
    :unscored,
    :transformed_content,
    :activity_to_source_selection_mapping
  ]
end
