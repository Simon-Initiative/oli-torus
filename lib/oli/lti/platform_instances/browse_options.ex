defmodule Oli.Lti.PlatformInstances.BrowseOptions do
  @moduledoc """
  Options for browsing platform instances.
  """

  defstruct [:text_search, :include_disabled]

  @type t() :: %__MODULE__{
          text_search: String.t() | nil,
          include_disabled: boolean()
        }
end
