defmodule Oli.Resources.PageContent.TraversalContext do
  @moduledoc """
  A struct that contains page content traversal context for the element
  currently being processed.
  """

  defstruct level: 0,
            group_id: nil,
            survey_id: nil,

            # The traversal will stop and not continue to recurse when it encounters
            # types (e.g. "p", "table") contained in this list.  It will apply the map_fn
            # to the element.
            stop_at_types: [],

            # The traversal will ignore elements of these types (e.g. "input_ref") and not
            # apply the map_fn to them.
            ignore_types: []

  @type t() :: %__MODULE__{
          level: Integer.t(),
          group_id: String.t() | nil,
          survey_id: String.t() | nil,
          stop_at_types: list(String.t()),
          ignore_types: list(String.t())
        }
end
