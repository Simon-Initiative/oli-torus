defmodule Oli.Content.Writers.Writer do
  alias Oli.Content.Writers.Context

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

  def render(%Context{} = context, content_list, impl) when is_list(content_list) do
    Enum.map(content_list, fn content -> render(context, content, impl) end)
  end

  def render(%Context{} = context, %{"type" => "content", "children" => children}, impl) do
    Enum.map(children, fn child -> render(context, child, impl) end)
  end

  @spec render(Oli.Content.Writers.Context.t(), maybe_improper_list | map, any) :: any
  def render(%Context{} = context, %{"text" => _text} = text_entity, impl) do
    impl.text(context, text_entity)
  end

  def render(%Context{} = context, children, impl) when is_list(children) do
    Enum.map(children, fn child -> render(context, child, impl) end)
  end

  def render(%Context{} = context, %{"type" => type, "children" => children} = entity, impl) do
    next = fn -> render(context, children, impl) end

    case type do
      "p" -> impl.p(context, next, entity)
      "h1" -> impl.h1(context, next, entity)
      "h2" -> impl.h2(context, next, entity)
      "h3" -> impl.h3(context, next, entity)
      "h4" -> impl.h4(context, next, entity)
      "h5" -> impl.h5(context, next, entity)
      "h6" -> impl.h6(context, next, entity)
      "img" -> impl.img(context, next, entity)
      "youtube" -> impl.youtube(context, next, entity)
      "audio" -> impl.audio(context, next, entity)
      "table" -> impl.table(context, next, entity)
      "tr" -> impl.tr(context, next, entity)
      "th" -> impl.th(context, next, entity)
      "td" -> impl.td(context, next, entity)
      "ol" -> impl.ol(context, next, entity)
      "ul" -> impl.ul(context, next, entity)
      "li" -> impl.li(context, next, entity)
      "math" -> impl.math(context, next, entity)
      "math_line" -> impl.math_line(context, next, entity)
      "code" -> impl.code(context, next, entity)
      "code_line" -> impl.code_line(context, next, entity)
      "blockquote" -> impl.blockquote(context, next, entity)
      "a" -> impl.a(context, next, entity)
    end
  end

end
