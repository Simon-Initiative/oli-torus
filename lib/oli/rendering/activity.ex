defmodule Oli.Rendering.Activity do
  @moduledoc """
  This modules defines the rendering functionality for an Oli activity. Rendering is
  extensibile to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `activity/html.ex`.
  """

  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t, String.t, String.t}) :: [any()]

  @doc """
  Renders an Oli activity given an activity-reference element and using the
  activity_map from context. Returns an IO list of raw html strings to be futher processed by
  Phoenix/BEAM writev.
  """
  def render(%Context{} = context, %{"activity_id" => _, "purpose" => _} = element, writer) do
    writer.activity(context, element)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  #can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    error_id = Utils.random_string(8)
    error_msg = "Activity is invalid: #{Kernel.inspect(element)}"
    if render_opts.log_errors, do: Logger.error("Render Error ##{error_id} #{error_msg}"), else: nil

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end

end
