defmodule OliWeb.Workspace.SubMenuItem do
  @moduledoc """
    Struct for a sub-menu item.
  """

  @enforce_keys [
    :text,
    :icon,
    :view,
    :parent_view,
    :children,
    :class
  ]

  defstruct [
    :text,
    :icon,
    :view,
    :parent_view,
    :children,
    :class
  ]

  @type t() :: %__MODULE__{
          text: String.t(),
          icon: String.t(),
          view: atom(),
          parent_view: atom(),
          children: list(%__MODULE__{}),
          class: String.t()
        }
end
