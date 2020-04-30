defmodule Oli.Rendering.Context do
  defstruct user: nil,
    activity_map: %{},
    render_opts: %{
      log_errors: true,
      render_errors: true,
    }
end
