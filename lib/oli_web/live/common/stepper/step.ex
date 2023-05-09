defmodule OliWeb.Common.Stepper.Step do
  defstruct title: nil,
            description: nil,
            render_fn: nil,
            on_next_step: nil,
            on_previous_step: nil,
            data: %{}
end
