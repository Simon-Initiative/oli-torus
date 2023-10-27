defmodule Oli.Rendering.Activity.Markdown do
  @moduledoc """
  Implements the Markdown writer for activity rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Activity

  def activity(
        _context,
        %{"activity_id" => activity_id} = _activity
      ) do
    ["\n", "Activity: #{activity_id}", "\n\n"]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
