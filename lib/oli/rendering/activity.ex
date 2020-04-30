defmodule Oli.Rendering.Activity do
  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t, String.t, String.t}) :: [any()]

  def render(%Context{} = context, %{"activity_id" => _, "purpose" => _} = element, writer) do
    writer.activity(context, element)
  end

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
