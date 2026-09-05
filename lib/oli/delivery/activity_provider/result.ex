defmodule Oli.Delivery.ActivityProvider.Result do
  defstruct [
    :errors,
    :prototypes,
    :bib_revisions,
    :unscored,
    :transformed_content,
    :alternative_groups_by_id,
    :experiment_decisions,
    :experiment_attributions
  ]
end
