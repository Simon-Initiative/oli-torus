defmodule Oli.Delivery.ActivityProvider.Result do
  defstruct [
    :errors,
    :revisions,
    :unscored,
    :transformed_content
  ]
end
