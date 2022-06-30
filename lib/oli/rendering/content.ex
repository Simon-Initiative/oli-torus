defmodule Oli.Rendering.Content do
  @moduledoc """
  This modules defines the rendering functionality for Oli structured content. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `content/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @type next :: (() -> String.t())
  @type children :: [%{}]

  @callback example(%Context{}, next, %{}) :: [any()]
  @callback learn_more(%Context{}, next, %{}) :: [any()]
  @callback manystudentswonder(%Context{}, next, %{}) :: [any()]
  @callback text(%Context{}, %{}) :: [any()]
  @callback p(%Context{}, next, %{}) :: [any()]
  @callback h1(%Context{}, next, %{}) :: [any()]
  @callback h2(%Context{}, next, %{}) :: [any()]
  @callback h3(%Context{}, next, %{}) :: [any()]
  @callback h4(%Context{}, next, %{}) :: [any()]
  @callback h5(%Context{}, next, %{}) :: [any()]
  @callback h6(%Context{}, next, %{}) :: [any()]
  @callback img(%Context{}, next, %{}) :: [any()]
  @callback img_inline(%Context{}, next, %{}) :: [any()]
  @callback youtube(%Context{}, next, %{}) :: [any()]
  @callback iframe(%Context{}, next, %{}) :: [any()]
  @callback audio(%Context{}, next, %{}) :: [any()]
  @callback table(%Context{}, next, %{}) :: [any()]
  @callback tr(%Context{}, next, %{}) :: [any()]
  @callback th(%Context{}, next, %{}) :: [any()]
  @callback td(%Context{}, next, %{}) :: [any()]
  @callback ol(%Context{}, next, %{}) :: [any()]
  @callback ul(%Context{}, next, %{}) :: [any()]
  @callback li(%Context{}, next, %{}) :: [any()]

  @callback formula(%Context{}, next, %{}) :: [any()]
  @callback formula_inline(%Context{}, next, %{}) :: [any()]

  @callback callout(%Context{}, next, %{}) :: [any()]
  @callback callout_inline(%Context{}, next, %{}) :: [any()]

  @callback math(%Context{}, next, %{}) :: [any()]
  @callback math_line(%Context{}, next, %{}) :: [any()]
  @callback code(%Context{}, next, %{}) :: [any()]
  @callback code_line(%Context{}, next, %{}) :: [any()]
  @callback blockquote(%Context{}, next, %{}) :: [any()]
  @callback a(%Context{}, next, %{}) :: [any()]
  @callback popup(%Context{}, next, %{}) :: [any()]
  @callback selection(%Context{}, next, %{}) :: [any()]
  @callback cite(%Context{}, next, %{}) :: [any()]

  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli content element that contains children.
  Returns an IO list of strings.

  Content elements with purposes attached are deprecated but the rendering code is
  left here to support these existing elements.
  """
  def render(
        %Context{} = context,
        %{"type" => "content", "children" => children, "purpose" => "example"} = element,
        writer
      ) do
    next = fn -> Enum.map(children, fn child -> render(context, child, writer) end) end
    writer.example(context, next, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "content", "children" => children, "purpose" => "learnmore"} = element,
        writer
      ) do
    next = fn -> Enum.map(children, fn child -> render(context, child, writer) end) end
    writer.learn_more(context, next, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "content", "children" => children, "purpose" => "manystudentswonder"} =
          element,
        writer
      ) do
    next = fn -> Enum.map(children, fn child -> render(context, child, writer) end) end
    writer.manystudentswonder(context, next, element)
  end

  def render(%Context{} = context, %{"type" => "content", "children" => children}, writer) do
    Enum.map(children, fn child -> render(context, child, writer) end)
  end

  # Renders text content
  def render(%Context{} = context, %{"text" => _text} = text_element, writer) do
    writer.text(context, text_element)
  end

  # Renders content children
  def render(%Context{} = context, children, writer) when is_list(children) do
    Enum.map(children, fn child -> render(context, child, writer) end)
  end

  def render(
        %Context{} = context,
        %{"type" => "formula", "children" => children} = element,
        writer
      ) do
    writer.formula(context, fn -> render(context, children, writer) end, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "formula"} = element,
        writer
      ) do
    writer.formula(context, nil, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "formula_inline", "children" => children} = element,
        writer
      ) do
    writer.formula_inline(context, fn -> render(context, children, writer) end, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "formula_inline"} = element,
        writer
      ) do
    writer.formula_inline(context, nil, element)
  end

  # Renders a content element by calling the provided writer implementation on a
  # supported element type.
  def render(
        %Context{render_opts: render_opts} = context,
        %{"type" => type, "children" => children} = element,
        writer
      ) do
    next = fn -> render(context, children, writer) end

    case type do
      "p" ->
        writer.p(context, next, element)

      "h1" ->
        writer.h1(context, next, element)

      "h2" ->
        writer.h2(context, next, element)

      "h3" ->
        writer.h3(context, next, element)

      "h4" ->
        writer.h4(context, next, element)

      "h5" ->
        writer.h5(context, next, element)

      "h6" ->
        writer.h6(context, next, element)

      "img" ->
        writer.img(context, next, element)

      "img_inline" ->
        writer.img_inline(context, next, element)

      "youtube" ->
        writer.youtube(context, next, element)

      "iframe" ->
        writer.iframe(context, next, element)

      "audio" ->
        writer.audio(context, next, element)

      "table" ->
        writer.table(context, next, element)

      "tr" ->
        writer.tr(context, next, element)

      "th" ->
        writer.th(context, next, element)

      "td" ->
        writer.td(context, next, element)

      "ol" ->
        writer.ol(context, next, element)

      "ul" ->
        writer.ul(context, next, element)

      "li" ->
        writer.li(context, next, element)

      "math" ->
        writer.math(context, next, element)

      "math_line" ->
        writer.math_line(context, next, element)

      "code" ->
        writer.code(context, next, element)

      "code_line" ->
        writer.code_line(context, next, element)

      "blockquote" ->
        writer.blockquote(context, next, element)

      "a" ->
        writer.a(context, next, element)

      "cite" ->
        writer.cite(context, next, element)

      "popup" ->
        writer.popup(context, next, element)

      "callout" ->
        writer.callout(context, next, element)

      "callout_inline" ->
        writer.callout_inline(context, next, element)

      _ ->
        {error_id, error_msg} = log_error("Content element type is not supported", element)

        if render_opts.render_errors do
          writer.error(context, element, {:unsupported, error_id, error_msg})
        else
          []
        end
    end
  end

  def render(%Context{} = context, %{"type" => "selection"} = selection, writer) do
    writer.selection(context, fn -> true end, selection)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Content element is invalid", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
