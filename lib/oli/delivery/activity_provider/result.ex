defmodule Oli.Delivery.ActivityProvider.Result do
  defstruct [
    :errors,
    :prototypes,
    :bib_revisions,
    :unscored,
    :transformed_content
  ]
end
