defmodule Oli.Lti.PlatformExternalTools.BrowseOptions do
  @moduledoc """
  Options for browsing platform external tools.
  """

  defstruct [:text_search, :include_disabled]

  @type t() :: %__MODULE__{
          text_search: String.t() | nil,
          include_disabled: boolean()
        }
end
