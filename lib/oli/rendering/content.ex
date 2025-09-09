defmodule Oli.Rendering.Content do
  @moduledoc """
  This modules defines the rendering functionality for Oli structured content. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `content/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @type next :: (-> String.t())
  @type children :: [%{}]

  @callback text(%Context{}, %{}) :: [any()]
  @callback input_ref(%Context{}, next, %{}) :: [any()]
  @callback p(%Context{}, next, %{}) :: [any()]
  @callback h1(%Context{}, next, %{}) :: [any()]
  @callback h2(%Context{}, next, %{}) :: [any()]
  @callback h3(%Context{}, next, %{}) :: [any()]
  @callback h4(%Context{}, next, %{}) :: [any()]
  @callback h5(%Context{}, next, %{}) :: [any()]
  @callback h6(%Context{}, next, %{}) :: [any()]
  @callback img(%Context{}, next, %{}) :: [any()]
  @callback img_inline(%Context{}, next, %{}) :: [any()]
  @callback video(%Context{}, next, %{}) :: [any()]
  @callback youtube(%Context{}, next, %{}) :: [any()]
  @callback iframe(%Context{}, next, %{}) :: [any()]
  @callback audio(%Context{}, next, %{}) :: [any()]
  @callback table(%Context{}, next, %{}) :: [any()]
  @callback tr(%Context{}, next, %{}) :: [any()]
  @callback th(%Context{}, next, %{}) :: [any()]
  @callback td(%Context{}, next, %{}) :: [any()]
  @callback tc(%Context{}, next, %{}) :: [any()]
  @callback ol(%Context{}, next, %{}) :: [any()]
  @callback ul(%Context{}, next, %{}) :: [any()]
  @callback li(%Context{}, next, %{}) :: [any()]
  @callback dl(%Context{}, next, next, %{}) :: [any()]
  @callback dt(%Context{}, next, %{}) :: [any()]
  @callback dd(%Context{}, next, %{}) :: [any()]

  @callback trigger(%Context{}, next, %{}) :: [any()]
  @callback command_button(%Context{}, next, %{}) :: [any()]
  @callback conjugation(%Context{}, next, next, %{}) :: [any()]

  @callback definition(%Context{}, next, next, next, %{}) ::
              [any()]
  @callback definition_meaning(%Context{}, next, %{}) :: [any()]
  @callback definition_translation(%Context{}, next, %{}) :: [any()]
  @callback pronunciation(%Context{}, next, %{}) :: [any()]

  @callback dialog(%Context{}, next, %{}) :: [any()]
  @callback dialog_line(%Context{}, next, %{}, %{}) :: [any()]

  @callback foreign(%Context{}, next, %{}) :: [any()]

  @callback formula(%Context{}, next, %{}) :: [any()]
  @callback formula_inline(%Context{}, next, %{}) :: [any()]

  @callback figure(%Context{}, next, next, %{}) :: [any()]

  @callback callout(%Context{}, next, %{}) :: [any()]
  @callback callout_inline(%Context{}, next, %{}) :: [any()]

  @callback math(%Context{}, next, %{}) :: [any()]
  @callback math_line(%Context{}, next, %{}) :: [any()]
  @callback code(%Context{}, next, %{}) :: [any()]
  @callback ecl(%Context{}, next, %{}) :: [any()]
  @callback code_line(%Context{}, next, %{}) :: [any()]
  @callback blockquote(%Context{}, next, %{}) :: [any()]
  @callback a(%Context{}, next, %{}) :: [any()]
  @callback page_link(%Context{}, next, %{}) :: [any()]
  @callback popup(%Context{}, next, %{}) :: [any()]
  @callback selection(%Context{}, next, %{}) :: [any()]
  @callback cite(%Context{}, next, %{}) :: [any()]

  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  DEPRECATED these content types are no longer used but remain here for backwards compatibility.
  Purpose specific content is now handled by using a Group with a purpose.
  """
  @callback example(%Context{}, next, %{}) :: [any()]
  @callback learn_more(%Context{}, next, %{}) :: [any()]
  @callback manystudentswonder(%Context{}, next, %{}) :: [any()]

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

  def render(
        %Context{} = context,
        %{"type" => "content", "children" => children} = element,
        writer
      ) do
    next = fn -> Enum.map(children, fn child -> render(context, child, writer) end) end
    writer.content(context, next, element)
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
    writer.formula(
      context,
      fn -> render(%Context{context | is_annotation_level: false}, children, writer) end,
      element
    )
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

  def render(
        %Context{} = context,
        %{"type" => "conjugation"} = element,
        writer
      ) do
    render_table = fn ->
      case element["table"] do
        nil -> []
        table -> render(%Context{context | is_annotation_level: false}, table, writer)
      end
    end

    render_pronunciation = fn ->
      case element["pronunciation"] do
        nil ->
          []

        pronunciation ->
          render(%Context{context | is_annotation_level: false}, pronunciation, writer)
      end
    end

    writer.conjugation(context, render_table, render_pronunciation, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "definition"} = element,
        writer
      ) do
    render_translation = fn ->
      case element["translations"] do
        nil ->
          []

        translations ->
          Enum.map(translations, fn child ->
            render(%Context{context | is_annotation_level: false}, child, writer)
          end)
      end
    end

    render_pronunciation = fn ->
      case element["pronunciation"] do
        nil ->
          []

        pronunciation ->
          render(%Context{context | is_annotation_level: false}, pronunciation, writer)
      end
    end

    render_meaning = fn ->
      case element["meanings"] do
        nil ->
          []

        meanings ->
          Enum.map(meanings, fn child ->
            render(%Context{context | is_annotation_level: false}, child, writer)
          end)
      end
    end

    writer.definition(context, render_translation, render_pronunciation, render_meaning, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "figure", "children" => children, "title" => title} = element,
        writer
      ) do
    render_children = fn ->
      render(%Context{context | is_annotation_level: false}, children, writer)
    end

    render_title = fn -> render(%Context{context | is_annotation_level: false}, title, writer) end
    writer.figure(context, render_children, render_title, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "dl", "items" => items, "title" => title} = element,
        writer
      ) do
    render_items = fn -> render(%Context{context | is_annotation_level: false}, items, writer) end
    render_title = fn -> render(%Context{context | is_annotation_level: false}, title, writer) end
    writer.dl(context, render_items, render_title, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "dl", "items" => items} = element,
        writer
      ) do
    render_items = fn -> render(%Context{context | is_annotation_level: false}, items, writer) end
    render_title = fn -> [] end
    writer.dl(context, render_items, render_title, element)
  end

  def render(
        %Context{} = context,
        %{"type" => "dialog"} = element,
        writer
      ) do
    render_lines = fn ->
      case element["lines"] do
        nil ->
          []

        lines ->
          Enum.map(lines, fn child ->
            render_line_content = fn ->
              render(%Context{context | is_annotation_level: false}, child["children"], writer)
            end

            writer.dialog_line(
              %Context{context | is_annotation_level: false},
              render_line_content,
              child,
              element
            )
          end)
      end
    end

    writer.dialog(context, render_lines, element)
  end

  # Renders a content element by calling the provided writer implementation on a
  # supported element type.
  def render(
        %Context{render_opts: render_opts} = context,
        %{"type" => type, "children" => children} = element,
        writer
      ) do
    next = fn -> render(%Context{context | is_annotation_level: false}, children, writer) end

    case type do
      "input_ref" ->
        writer.input_ref(context, next, element)

      "p" ->
        # check if the paragraph is empty and if so, don't render it
        if is_empty_paragraph?(element) do
          []
        else
          writer.p(context, next, element)
        end

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

      "video" ->
        writer.video(context, next, element)

      "ecl" ->
        writer.ecl(context, next, element)

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

      "tc" ->
        writer.tc(context, next, element)

      "ol" ->
        # allow annotation bubbles to be rendered on list items
        next = fn -> render(context, children, writer) end

        writer.ol(context, next, element)

      "ul" ->
        # allow annotation bubbles to be rendered on list items
        next = fn -> render(context, children, writer) end

        writer.ul(context, next, element)

      "li" ->
        writer.li(context, next, element)

      "dt" ->
        writer.dt(context, next, element)

      "dd" ->
        writer.dd(context, next, element)

      "math" ->
        writer.math(context, next, element)

      "math_line" ->
        writer.math_line(context, next, element)

      "code" ->
        writer.code(context, next, element)

      "code_line" ->
        writer.code_line(context, next, element)

      "command_button" ->
        writer.command_button(context, next, element)

      "trigger" ->
        writer.trigger(context, next, element)

      "blockquote" ->
        writer.blockquote(context, next, element)

      "a" ->
        writer.a(context, next, element)

      "page_link" ->
        writer.page_link(context, next, element)

      "cite" ->
        writer.cite(context, next, element)

      "popup" ->
        writer.popup(context, next, element)

      "callout" ->
        writer.callout(context, next, element)

      "callout_inline" ->
        writer.callout_inline(context, next, element)

      "meaning" ->
        writer.definition_meaning(context, next, element)

      "translation" ->
        writer.definition_translation(context, next, element)

      "pronunciation" ->
        writer.pronunciation(context, next, element)

      "foreign" ->
        writer.foreign(context, next, element)

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

  # Renders content elements that have a model field containing an array of content elements
  def render(%Context{} = context, %{"model" => model} = _element, writer) when is_list(model) do
    render(context, model, writer)
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

  defp is_empty_paragraph?(%{"type" => "p", "children" => children}) do
    Enum.all?(children, fn child ->
      child["text"] && String.trim(child["text"]) == ""
    end)
  end

  defp is_empty_paragraph?(_), do: false
end
