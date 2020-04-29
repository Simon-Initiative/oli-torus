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

  def render(%Context{} = context, %{"type" => "content", "children" => children}, format) do
    Enum.map(children, fn child -> render(context, child, format) end)
  end

  @spec render(Context.t(), maybe_improper_list | map, any) :: any
  def render(%Context{} = context, %{"text" => _text} = text_entity, format) do
    format.text(context, text_entity)
  end

  def render(%Context{} = context, children, format) when is_list(children) do
    Enum.map(children, fn child -> render(context, child, format) end)
  end

  def render(%Context{} = context, %{"type" => type, "children" => children} = entity, format) do
    next = fn -> render(context, children, format) end

    case type do
      "p" -> format.p(context, next, entity)
      "h1" -> format.h1(context, next, entity)
      "h2" -> format.h2(context, next, entity)
      "h3" -> format.h3(context, next, entity)
      "h4" -> format.h4(context, next, entity)
      "h5" -> format.h5(context, next, entity)
      "h6" -> format.h6(context, next, entity)
      "img" -> format.img(context, next, entity)
      "youtube" -> format.youtube(context, next, entity)
      "audio" -> format.audio(context, next, entity)
      "table" -> format.table(context, next, entity)
      "tr" -> format.tr(context, next, entity)
      "th" -> format.th(context, next, entity)
      "td" -> format.td(context, next, entity)
      "ol" -> format.ol(context, next, entity)
      "ul" -> format.ul(context, next, entity)
      "li" -> format.li(context, next, entity)
      "math" -> format.math(context, next, entity)
      "math_line" -> format.math_line(context, next, entity)
      "code" -> format.code(context, next, entity)
      "code_line" -> format.code_line(context, next, entity)
      "blockquote" -> format.blockquote(context, next, entity)
      "a" -> format.a(context, next, entity)
      _ -> format.unsupported(context, entity)
    end
  end

end
