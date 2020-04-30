defmodule Oli.Rendering.Page do
  alias Oli.Utils
  alias Oli.Rendering.Context

  require Logger

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t, String.t, String.t}) :: [any()]

  def render(%Context{render_opts: render_opts} = context, page_model, writer) when is_list(page_model) do
    Enum.map(page_model, fn element ->
      case element do
        %{"type" => "content"} ->
          writer.content(context, element)
        %{"type" => "activity-reference"} ->
          writer.activity(context, element)
        _ ->
          error_id = Utils.random_string(8)
          error_msg = "Page item is not supported: #{Kernel.inspect(element)}"
          if render_opts.log_errors, do: Logger.error("Render Error ##{error_id} #{error_msg}"), else: nil

          if render_opts.render_errors do
            writer.error(context, element, {:unsupported, error_id, error_msg})
          else
            []
          end
      end
    end)
  end

  def render(%Context{render_opts: render_opts} = context, page_model, writer) do
    error_id = Utils.random_string(8)
    error_msg = "Page model is invalid: #{Kernel.inspect(page_model)}"
    if render_opts.log_errors, do: Logger.error("Render Error ##{error_id} #{error_msg}"), else: nil

    if render_opts.render_errors do
      writer.error(context, page_model, {:invalid_page_model, error_id, error_msg})
    else
      []
    end
  end

end
