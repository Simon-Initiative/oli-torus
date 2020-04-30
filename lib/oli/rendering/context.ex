defmodule Oli.Rendering.Context do
  defstruct user: nil, activity_map: %{}, render_opts: %{render_unsupported: true, render_invalid: true, log_issues: true}
end
