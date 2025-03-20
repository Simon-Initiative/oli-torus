defmodule Oli.Rendering.LTIExternalTool do
  @moduledoc """
  This modules defines the rendering functionality for an LTI External Tool. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `lti_external_tool/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @callback lti_external_tool(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {atom(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an LTI external tool given an lti-external-tool element and using the
  lti_external_tools map from context. Returns an IO list of strings.
  """
  def render(%Context{} = context, element, writer) do
    writer.lti_external_tool(context, element)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("LTI External Tool render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
