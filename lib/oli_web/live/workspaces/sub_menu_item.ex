defmodule OliWeb.Workspace.SubMenuItem do
  @moduledoc """
    Struct for a sub-menu item.
  """
  @enforce_keys [:text, :view]
  @optional_keys [parent_view: nil, icon: nil, children: []]

  defstruct @enforce_keys ++ @optional_keys

  @type t() :: %__MODULE__{
          text: String.t(),
          view: atom(),
          icon: String.t(),
          parent_view: atom(),
          children: list(%__MODULE__{})
        }
end
