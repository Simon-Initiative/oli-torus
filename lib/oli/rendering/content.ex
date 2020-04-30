defmodule Oli.Rendering.Content do
  alias Oli.Rendering.Context

  require Logger

  @type next :: (() -> String.t())
  @type children :: [%{}]

  @callback text(%Context{}, %{}) :: [any()]
  @callback p(%Context{}, next, %{}) :: [any()]
  @callback h1(%Context{}, next, %{}) :: [any()]
  @callback h2(%Context{}, next, %{}) :: [any()]
  @callback h3(%Context{}, next, %{}) :: [any()]
  @callback h4(%Context{}, next, %{}) :: [any()]
  @callback h5(%Context{}, next, %{}) :: [any()]
  @callback h6(%Context{}, next, %{}) :: [any()]
  @callback img(%Context{}, next, %{}) :: [any()]
  @callback youtube(%Context{}, next, %{}) :: [any()]
  @callback audio(%Context{}, next, %{}) :: [any()]
  @callback table(%Context{}, next, %{}) :: [any()]
  @callback tr(%Context{}, next, %{}) :: [any()]
  @callback th(%Context{}, next, %{}) :: [any()]
  @callback td(%Context{}, next, %{}) :: [any()]
  @callback ol(%Context{}, next, %{}) :: [any()]
  @callback ul(%Context{}, next, %{}) :: [any()]
  @callback li(%Context{}, next, %{}) :: [any()]
  @callback math(%Context{}, next, %{}) :: [any()]
  @callback math_line(%Context{}, next, %{}) :: [any()]
  @callback code(%Context{}, next, %{}) :: [any()]
  @callback code_line(%Context{}, next, %{}) :: [any()]
  @callback blockquote(%Context{}, next, %{}) :: [any()]
  @callback a(%Context{}, next, %{}) :: [any()]
  @callback unsupported(%Context{}, %{}) :: [any()]
  @callback invalid(%Context{}, %{}) :: [any()]

  def render(%Context{} = context, %{"type" => "content", "children" => children}, format) do
    Enum.map(children, fn child -> render(context, child, format) end)
  end

  def render(%Context{} = context, %{"text" => _text} = text_element, format) do
    format.text(context, text_element)
  end

  def render(%Context{} = context, children, format) when is_list(children) do
    Enum.map(children, fn child -> render(context, child, format) end)
  end

  def render(%Context{render_opts: render_opts} = context, %{"type" => type, "children" => children} = element, format) do
    next = fn -> render(context, children, format) end

    case type do
      "p" -> format.p(context, next, element)
      "h1" -> format.h1(context, next, element)
      "h2" -> format.h2(context, next, element)
      "h3" -> format.h3(context, next, element)
      "h4" -> format.h4(context, next, element)
      "h5" -> format.h5(context, next, element)
      "h6" -> format.h6(context, next, element)
      "img" -> format.img(context, next, element)
      "youtube" -> format.youtube(context, next, element)
      "audio" -> format.audio(context, next, element)
      "table" -> format.table(context, next, element)
      "tr" -> format.tr(context, next, element)
      "th" -> format.th(context, next, element)
      "td" -> format.td(context, next, element)
      "ol" -> format.ol(context, next, element)
      "ul" -> format.ul(context, next, element)
      "li" -> format.li(context, next, element)
      "math" -> format.math(context, next, element)
      "math_line" -> format.math_line(context, next, element)
      "code" -> format.code(context, next, element)
      "code_line" -> format.code_line(context, next, element)
      "blockquote" -> format.blockquote(context, next, element)
      "a" -> format.a(context, next, element)
      _ ->
        if render_opts.log_issues, do: Logger.warn("Element is not supported: #{Kernel.inspect(element)}"), else: nil

        if render_opts.render_unsupported do
          format.unsupported(context, element)
        else
          []
        end
    end
  end

  def render(%Context{render_opts: render_opts} = context, element, format) do
    if render_opts.log_issues, do: Logger.warn("Element is invalid: #{Kernel.inspect(element)}"), else: nil

    if render_opts.render_invalid do
      format.invalid(context, element)
    else
      []
    end
  end

end
