defmodule Oli.Rendering.Context do
  @moduledoc """
  The context struct that is used by the renderers contains useful
  data that may change the way rendering occurs. It is intended to be read-only
  by the renderers
  """
  defstruct user: nil,
    activity_map: %{},
    render_opts: %{
      log_errors: true,
      render_errors: true,
    }
end
