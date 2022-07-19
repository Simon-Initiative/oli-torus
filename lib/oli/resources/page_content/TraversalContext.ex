defmodule Oli.Resources.PageContent.TraversalContext do
  @moduledoc """
  A struct that contains page content traversal context for the element
  currently being processed.
  """

  defstruct level: 0,
            group_id: nil,
            survey_id: nil

  @type t() :: %__MODULE__{
          level: Integer.t(),
          group_id: String.t() | nil,
          survey_id: String.t() | nil
        }
end
