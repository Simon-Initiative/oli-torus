defmodule Oli.Rendering.Page do
  @moduledoc """
  This modules defines the rendering functionality for an Oli page. Rendering is
  extensibile to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `page/html.ex`.
  """
  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of raw html strings to be futher processed by Phoenix/BEAM writev.
  """
  def render(%Context{render_opts: render_opts} = context, page_model, writer)
      when is_list(page_model) do
    Enum.map(page_model, fn element ->
      case element do
        %{"type" => "content"} ->
          writer.content(context, element)

        %{"type" => "activity-reference"} ->
          writer.activity(context, element)

        _ ->
          error_id = Utils.random_string(8)
          error_msg = "Page item is not supported: #{Kernel.inspect(element)}"

          if render_opts.log_errors,
            do: Logger.error("Render Error ##{error_id} #{error_msg}"),
            else: nil

          if render_opts.render_errors do
            writer.error(context, element, {:unsupported, error_id, error_msg})
          else
            []
          end
      end
    end)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, page_model, writer) do
    error_id = Utils.random_string(8)
    error_msg = "Page model is invalid: #{Kernel.inspect(page_model)}"

    if render_opts.log_errors,
      do: Logger.error("Render Error ##{error_id} #{error_msg}"),
      else: nil

    if render_opts.render_errors do
      writer.error(context, page_model, {:invalid_page_model, error_id, error_msg})
    else
      []
    end
  end
end
