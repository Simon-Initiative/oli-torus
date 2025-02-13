defmodule Oli.Rendering.Content.Markdown do
  @moduledoc """
  Implements the Html writer for Oli content rendering.

  Important: any changes to this file must be replicated in writers/html.ts for activity rendering.
  """
  import Oli.Utils
  import Oli.Rendering.Utils

  alias Oli.Rendering.Context
  alias Phoenix.HTML
  alias Oli.Rendering.Content.MathMLSanitizer
  alias HtmlSanitizeEx.Scrubber

  @behaviour Oli.Rendering.Content

  defp adhoc_group(label, content) do
    [
      "---\n",
      "##### #{label}\n",
      content,
      "---\n\n"
    ]
  end

  def content(%Context{} = _context, next, _) do
    next.()
  end

  def callout(%Oli.Rendering.Context{} = _context, next, _) do
    adhoc_group("Callout", next.())
  end

  def callout_inline(%Oli.Rendering.Context{} = _context, next, _) do
    next.()
  end

  def trigger(%Context{} = _context, _, _attrs) do
    [""]
  end

  def p(%Context{} = _context, next, _) do
    [
      next.(),
      "\n\n"
    ]
  end

  def input_ref(%Context{} = _context, _next, _) do
    [
      "[user input]"
    ]
  end

  def h1(%Context{} = _context, next, _) do
    [
      "# ",
      next.(),
      "\n\n"
    ]
  end

  def h2(%Context{} = _context, next, _) do
    [
      "## ",
      next.(),
      "\n\n"
    ]
  end

  def h3(%Context{} = _context, next, _) do
    [
      "### ",
      next.(),
      "\n\n"
    ]
  end

  def h4(%Context{} = _context, next, _) do
    [
      "#### ",
      next.(),
      "\n\n"
    ]
  end

  def h5(%Context{} = _context, next, _) do
    [
      "##### ",
      next.(),
      "\n\n"
    ]
  end

  def h6(%Context{} = _context, next, _) do
    [
      "###### ",
      next.(),
      "\n\n"
    ]
  end

  def img(%Context{} = _context, _, %{"src" => src} = attrs) do
    [
      "![#{maybeAlt(attrs)}](#{escape_xml!(src)})\n\n"
    ]
  end

  def img(%Context{} = _context, _, _e), do: ""

  def img_inline(%Context{} = _context, _, %{"src" => src} = attrs) do
    [
      "![#{maybeAlt(attrs)}](#{escape_xml!(src)})\n\n"
    ]
  end

  def img_inline(%Context{} = _context, _, _e), do: ""

  def video(%Context{} = _context, _, attrs) do
    adhoc_group("Video", maybeAlt(attrs))
  end

  def ecl(%Context{} = _context, _, attrs) do
    adhoc_group("Emerald Cloud Lab Code", ["```\n", attrs["code"], "```\n\n"])
  end

  def youtube(%Context{} = _context, _, %{"src" => src} = attrs) do
    adhoc_group("YouTube Video", [maybeAlt(attrs), "\n", "source: #{src}"])
  end

  def youtube(%Context{} = _context, _, _e), do: ""

  def iframe(%Context{} = _context, _, %{"src" => src} = attrs) do
    adhoc_group("External WebPage IFRAME", [maybeAlt(attrs), "\n", "source: #{escape_xml!(src)}"])
  end

  def iframe(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  def audio(%Context{} = _context, _, %{"src" => src} = attrs) do
    adhoc_group("Audio Clip", [maybeAlt(attrs), "\n", "source: #{src}"])
  end

  def audio(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  def table(%Context{} = _context, next, _attrs) do
    [
      "\n",
      next.(),
      "\n\n"
    ]
  end

  def tr(%Context{} = _context, next, _) do
    ["\n|", next.()]
  end

  def th(%Context{} = _context, next, _attrs) do
    [next.(), "|"]
  end

  def td(%Context{} = _context, next, _attrs) do
    [next.(), "|"]
  end

  def tc(%Context{} = _context, next, _attrs) do
    [next.(), "|"]
  end

  def ol(%Context{} = _context, next, %{"style" => _style}) do
    ["\n", next.(), "\n\n"]
  end

  def ol(%Context{} = _context, next, _) do
    ["\n", next.(), "\n\n"]
  end

  def dl(%Context{}, next, title, %{}) do
    ["\n", "definition list: #{title.()}", "\n", next.(), "\n\n"]
  end

  def dt(%Context{}, next, %{}) do
    [next.(), "\n"]
  end

  def dd(%Context{}, next, %{}) do
    [": ", next.(), "\n"]
  end

  def ul(%Context{} = _context, next, %{"style" => _style}) do
    ["\n", next.(), "\n\n"]
  end

  def ul(%Context{} = _context, next, _) do
    ["\n", next.(), "\n\n"]
  end

  def li(%Context{} = _context, next, _) do
    ["1. ", next.(), "\n"]
  end

  def conjugation(%Oli.Rendering.Context{}, render_table, _render_pronunciation, attrs) do
    title =
      case attrs["title"] do
        nil -> ""
        title -> title
      end

    verb =
      case attrs["verb"] do
        nil -> ""
        verb -> verb
      end

    adhoc_group("Conjugation", [title, "\n", "verb: #{verb}\n", render_table.()])
  end

  def dialog(%Context{}, next, %{"title" => title}) do
    adhoc_group("Dialog", [title, "\n", next.()])
  end

  def dialog(%Context{}, next, _) do
    adhoc_group("Dialog", next.())
  end

  def dialog_speaker_portrait(image) do
    [
      "![dialog speaker portrait](#{escape_xml!(image)})\n\n"
    ]
  end

  def dialog_speaker_portrait() do
    ""
  end

  def dialog_speaker(speaker_id, %{"speakers" => speakers}) do
    speaker = Enum.find(speakers, fn speaker -> speaker["id"] == speaker_id end)

    case speaker do
      %{"name" => name, "image" => image} ->
        [dialog_speaker_portrait(image), "Speaker: ", name, "\n"]

      %{"name" => name} ->
        [dialog_speaker_portrait(), "Speaker: ", name, "\n"]

      _ ->
        ["Speaker: Unknown Speaker \n"]
    end ++
      ["</div>"]
  end

  def dialog_line_class(speaker_id, %{"speakers" => speakers}) do
    speaker_index = Enum.find_index(speakers, fn speaker -> speaker["id"] == speaker_id end)

    case speaker_index do
      nil -> "speaker-1"
      _ -> "speaker-#{rem(speaker_index, 5) + 1}"
    end
  end

  def dialog_line_class(_, _), do: "speaker-1"

  def dialog_line(%Context{}, next, %{"speaker" => speaker_id}, dialog) do
    [
      dialog_speaker(speaker_id, dialog),
      next.(),
      "\n"
    ]
  end

  def definition_meaning(%Context{} = _context, next, _) do
    ["Meaning: ", next.(), "\n"]
  end

  def definition_translation(%Context{} = _context, next, _) do
    ["Translation: ", next.(), "\n"]
  end

  def pronunciation(%Context{} = _context, next, _element) do
    ["Pronunciation: ", next.()]
  end

  def definition(
        %Context{} = _context,
        render_translation,
        render_pronunciation,
        render_meaning,
        %{"term" => term} = _element
      ) do
    adhoc_group("Definition", [
      term,
      "\n",
      render_pronunciation.(),
      render_translation.(),
      render_meaning.()
    ])
  end

  def foreign(
        %Oli.Rendering.Context{learning_language: _learning_language},
        next,
        _attrs
      ) do
    next.()
  end

  def formula_class(false), do: "formula"
  def formula_class(true), do: "formula-inline"

  def formula(context, next, properties, inline \\ false)

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src, "legacyBlockRendered" => true},
        true
      ) do
    ["$$ ", escape_xml!(src), " $$\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src},
        true
      ) do
    ["$$ ", escape_xml!(src), " $$\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src},
        false
      ) do
    ["$$ ", escape_xml!(src), " $$\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "mathml", "src" => src},
        _inline
      ) do
    [
      Scrubber.scrub(src, MathMLSanitizer),
      "\n"
    ]
  end

  def figure(%Context{} = _context, render_children, render_title, _) do
    [
      render_title.(),
      "\n",
      render_children.(),
      "\n"
    ]
  end

  def formula_inline(context, next, map) do
    formula(context, next, map, true)
  end

  def math(%Context{} = _context, next, _) do
    ["$$ ", next.(), " $$\n"]
  end

  def math_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  # V2 - presence of "code" attr
  def code(
        %Context{} = _context,
        _next,
        %{
          "language" => language,
          "code" => code
        } = _attrs
      ) do
    safe_language = escape_xml!(language)

    language =
      if Map.has_key?(code_languages(), safe_language) do
        Map.get(code_languages(), safe_language)
      else
        "text"
      end

    [
      "```#{language}\n",
      escape_xml!(code),
      "\n```\n"
    ]
  end

  # V1 - content as children
  def code(
        %Context{} = _context,
        next,
        %{
          "language" => language
        } = _attrs
      ) do
    safe_language = escape_xml!(language)

    language =
      if Map.has_key?(code_languages(), safe_language) do
        Map.get(code_languages(), safe_language)
      else
        "text"
      end

    [
      "```#{language}\n",
      next.(),
      "\n```\n"
    ]
  end

  def code(
        %Context{} = _dcontext,
        next,
        attrs
      ) do
    {_error_id, _error_msg} =
      log_error("Malformed content element. Missing language attribute", attrs)

    [
      "```\n",
      next.(),
      "\n```\n"
    ]
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  def command_button(%Context{} = _context, _next, _) do
    ""
  end

  def blockquote(%Context{} = _context, next, _) do
    ["> ", next.(), "\n\n"]
  end

  def a(%Context{} = context, next, %{"href" => href}) do
    if String.starts_with?(href, "/course/link") do
      internal_link(context, next, href)
    else
      external_link(context, next, href)
    end
  end

  def a(%Context{} = _context, next, _attrs) do
    next.()
  end

  defp internal_link(
         %Context{section_slug: section_slug, mode: mode, project_slug: project_slug},
         next,
         href,
         _opts \\ []
       ) do
    href =
      case section_slug do
        nil ->
          case mode do
            :author_preview ->
              "/authoring/project/#{project_slug}/preview/#{revision_slug_from_course_link(href)}"

            _ ->
              "#"
          end

        section_slug ->
          # rewrite internal link using section slug and revision slug
          case mode do
            :instructor_preview ->
              "/sections/#{section_slug}/preview/page/#{revision_slug_from_course_link(href)}"

            _ ->
              "/sections/#{section_slug}/page/#{revision_slug_from_course_link(href)}"
          end
      end

    ["[", next.(), "](#{href})"]
  end

  defp external_link(%Context{} = _context, next, href) do
    ["[", next.(), "](#{href})"]
  end

  def page_link(%Context{} = _context, _next, %{
        "idref" => _idref
      }) do
    [""]
  end

  def cite(%Context{} = _context, next, _a) do
    next.()
  end

  def popup(%Context{} = _context, _next, _element) do
    []
  end

  def selection(%Context{} = _context, _, _selection) do
    []
  end

  defp revision_slug_from_course_link(href) do
    href
    |> String.replace_prefix("/course/link/", "")
  end

  def text(%Context{} = _context, %{"text" => text} = text_entity) do
    escape_xml!(text) |> wrap_with_marks(text_entity)
  end

  def error(%Context{} = _context, _element, _error) do
    "rendering error\n\n"
  end

  def example(%Context{} = _context, next, _) do
    adhoc_group("Example", next.())
  end

  def learn_more(%Context{} = _context, next, _) do
    adhoc_group("Learn More", next.())
  end

  def manystudentswonder(%Context{} = _context, next, _) do
    adhoc_group("Many Students Wonder", next.())
  end

  def escape_xml!(text) do
    case HTML.html_escape(text) do
      {:safe, result} -> result
    end
  end

  defp wrap_with_marks(text, text_entity) do
    supported_mark_tags = %{
      "em" => "*",
      "strong" => "**",
      "mark" => "==",
      "del" => "",
      "var" => "",
      "term" => "",
      "code" => "`",
      "sub" => "~",
      "doublesub" => "",
      "deemphasis" => "",
      "sup" => "^",
      "underline" => "",
      "strikethrough" => "~~"
    }

    marks =
      Map.keys(text_entity)
      # only include marks that are set to true
      |> Enum.filter(fn attr_name -> Map.get(text_entity, attr_name) == true end)
      # convert mark to tag name
      |> Enum.map(fn attr_name -> Map.get(supported_mark_tags, attr_name) end)
      # filter out any unsupported marks
      |> Enum.filter(fn mark -> mark != nil end)

    Enum.reverse(marks)
    |> Enum.reduce(
      text,
      fn mark, acc ->
        case mark do
          _ -> "#{mark}#{acc}#{mark}"
        end
      end
    )
  end

  defp missing_media_src(%Context{render_opts: render_opts} = context, element) do
    {error_id, error_msg} = log_error("Malformed content element. Missing src attribute", element)

    if render_opts.render_errors do
      error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end

  defp maybeAlt(attrs) do
    case attrs do
      %{"alt" => alt} -> escape_xml!(alt)
      _ -> ""
    end
  end
end
