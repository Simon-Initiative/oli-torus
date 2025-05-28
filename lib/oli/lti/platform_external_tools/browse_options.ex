defmodule Oli.Lti.PlatformExternalTools.BrowseOptions do
  @moduledoc """
  Options for browsing platform external tools.
  """

  defstruct [:text_search, :include_disabled, :include_deleted]

  @type t() :: %__MODULE__{
          text_search: String.t() | nil,
          include_disabled: boolean(),
          include_deleted: boolean()
        }
end
