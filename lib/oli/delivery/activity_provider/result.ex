defmodule Oli.Delivery.ActivityProvider.Result do
  defstruct [
    :errors,
    :revisions,
    :bib_revisions,
    :unscored,
    :transformed_content
  ]
end
