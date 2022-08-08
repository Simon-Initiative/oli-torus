defmodule Oli.Rendering.Content.Html do
  @moduledoc """
  Implements the Html writer for Oli content rendering.

  Important: any changes to this file must be replicated in writers/html.ts for activity rendering.
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Phoenix.HTML
  alias Oli.Rendering.Content.MathMLSanitizer
  alias HtmlSanitizeEx.Scrubber
  import Oli.Rendering.Utils

  @behaviour Oli.Rendering.Content

  def callout(%Oli.Rendering.Context{} = _context, next, _) do
    ["<span class=\"callout-block\">", next.(), "</span>\n"]
  end

  def callout_inline(%Oli.Rendering.Context{} = _context, next, _) do
    ["<span class=\"callout-inline\">", next.(), "</span>\n"]
  end

  def p(%Context{} = _context, next, _) do
    ["<p>", next.(), "</p>\n"]
  end

  def h1(%Context{} = _context, next, _) do
    ["<h1>", next.(), "</h1>\n"]
  end

  def h2(%Context{} = _context, next, _) do
    ["<h2>", next.(), "</h2>\n"]
  end

  def h3(%Context{} = _context, next, _) do
    ["<h3>", next.(), "</h3>\n"]
  end

  def h4(%Context{} = _context, next, _) do
    ["<h4>", next.(), "</h4>\n"]
  end

  def h5(%Context{} = _context, next, _) do
    ["<h5>", next.(), "</h5>\n"]
  end

  def h6(%Context{} = _context, next, _) do
    ["<h6>", next.(), "</h6>\n"]
  end

  def img(%Context{} = context, _, %{"src" => src} = attrs) do
    figure(context, attrs, [
      ~s|<img class="figure-img img-fluid"#{maybeAlt(attrs)}#{maybeWidth(attrs)} src="#{escape_xml!(src)}"/>\n|
    ])
  end

  def img(%Context{} = _context, _, _e), do: ""

  def img_inline(%Context{} = _context, _, %{"src" => src} = attrs) do
    [
      ~s|<img class="img-fluid"#{maybeAlt(attrs)}#{maybeWidth(attrs)} src="#{escape_xml!(src)}"/>\n|
    ]
  end

  def img_inline(%Context{} = _context, _, _e), do: ""

  def video(%Context{} = _context, _, attrs) do
    {:safe, video_player} =
      ReactPhoenix.ClientSide.react_component("Components.VideoPlayer", %{"video" => attrs})

    video_player
  end

  def youtube(%Context{} = context, _, %{"src" => src} = attrs) do
    iframe(
      context,
      nil,
      Map.put(attrs, "src", "https://www.youtube.com/embed/#{escape_xml!(src)}")
    )
  end

  def youtube(%Context{} = _context, _, _e), do: ""

  def iframe(%Context{} = context, _, %{"src" => src} = attrs) do
    iframe_width =
      if attrs["width"] do
        " style=\"width: #{escape_xml!(attrs["width"])}px\""
      else
        ""
      end

    figure(context, attrs, [
      """
      <div class="embed-responsive embed-responsive-16by9"#{iframe_width}>
        <iframe#{maybeAlt(attrs)} class="embed-responsive-item" allowfullscreen src="#{escape_xml!(src)}"></iframe>
      </div>
      """
    ])
  end

  def iframe(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  def audio(%Context{} = context, _, %{"src" => src} = attrs) do
    figure(context, attrs, [~s|<audio controls src="#{escape_xml!(src)}">
      Your browser does not support the <code>audio</code> element.
    </audio>\n|])
  end

  def audio(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  defp tableBorderClass(%{"border" => "hidden"}), do: "table-borderless"
  defp tableBorderClass(_), do: ""

  defp tableRowClass(%{"rowstyle" => "alternating"}), do: "table-striped"
  defp tableRowClass(_), do: ""

  def table(%Context{} = context, next, attrs) do
    caption =
      case attrs do
        %{"caption" => c} -> caption(context, c)
        _ -> ""
      end

    [
      "<table class='#{tableBorderClass(attrs)} #{tableRowClass(attrs)}'>#{caption}",
      next.(),
      "</table>\n"
    ]
  end

  def tr(%Context{} = _context, next, _) do
    ["<tr>", next.(), "</tr>\n"]
  end

  defp maybeColSpan(%{"colspan" => colspan}) do
    " colspan='#{colspan}'"
  end

  defp maybeColSpan(_) do
    ""
  end

  defp maybeRowSpan(%{"rowspan" => rowspan}) do
    " rowspan='#{rowspan}'"
  end

  defp maybeRowSpan(_) do
    ""
  end

  defp maybeTextAlign(%{"align" => alignment}) do
    " class='text-#{alignment}'"
  end

  defp maybeTextAlign(_) do
    ""
  end

  defp maybeAlign(attrs) do
    maybeColSpan(attrs) <> maybeRowSpan(attrs) <> maybeTextAlign(attrs)
  end

  def th(%Context{} = _context, next, attrs) do
    ["<th#{maybeAlign(attrs)}>", next.(), "</th>\n"]
  end

  def td(%Context{} = _context, next, attrs) do
    ["<td#{maybeAlign(attrs)}>", next.(), "</td>\n"]
  end

  def ol(%Context{} = _context, next, %{"style" => style}) do
    ["<ol class=\"list-#{style}\">", next.(), "</ol>\n"]
  end

  def ol(%Context{} = _context, next, _) do
    ["<ol>", next.(), "</ol>\n"]
  end

  def ul(%Context{} = _context, next, %{"style" => style}) do
    ["<ul class=\"list-#{style}\">", next.(), "</ul>\n"]
  end

  def ul(%Context{} = _context, next, _) do
    ["<ul>", next.(), "</ul>\n"]
  end

  def li(%Context{} = _context, next, _) do
    ["<li>", next.(), "</li>\n"]
  end

  def formula_class(false), do: "formula"
  def formula_class(true), do: "formula-inline"

  def formula(context, next, properties, inline \\ false)

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src},
        true
      ) do
    ["<span class=\"#{formula_class(true)}\">\\(", escape_xml!(src), "\\)</span>\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src},
        false
      ) do
    ["<span class=\"#{formula_class(false)}\">\\[", escape_xml!(src), "\\]</span>\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "mathml", "src" => src},
        inline
      ) do
    [
      "<span class=\"#{formula_class(inline)}\">",
      Scrubber.scrub(src, MathMLSanitizer),
      "</span>\n"
    ]
  end

  def formula_inline(context, next, map) do
    formula(context, next, map, true)
  end

  def math(%Context{} = _context, next, _) do
    ["<div>\\[", next.(), "\\]</div>\n"]
  end

  def math_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  # V2 - presence of "code" attr
  def code(
        %Context{} = context,
        _next,
        %{
          "language" => language,
          "code" => code
        } = attrs
      ) do
    safe_language = escape_xml!(language)

    language =
      if Map.has_key?(code_languages(), safe_language) do
        Map.get(code_languages(), safe_language)
      else
        "text"
      end

    figure(context, attrs, [
      ~s|<pre><code class="language-#{language}">#{escape_xml!(code)}</code></pre>\n|
    ])
  end

  # V1 - content as children
  def code(
        %Context{} = context,
        next,
        %{
          "language" => language
        } = attrs
      ) do
    safe_language = escape_xml!(language)

    language =
      if Map.has_key?(code_languages(), safe_language) do
        Map.get(code_languages(), safe_language)
      else
        "text"
      end

    figure(context, attrs, [
      ~s|<pre><code class="language-#{language}">|,
      next.(),
      "</code></pre>\n"
    ])
  end

  def code(
        %Context{} = context,
        next,
        attrs
      ) do
    {_error_id, _error_msg} =
      log_error("Malformed content element. Missing language attribute", attrs)

    figure(context, attrs, [
      ~s|<pre><code class="language-none">|,
      next.(),
      "</code></pre>\n"
    ])
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  def blockquote(%Context{} = _context, next, _) do
    ["<blockquote>", next.(), "</blockquote>\n"]
  end

  def a(%Context{} = context, next, %{"href" => href}) do
    if String.starts_with?(href, "/course/link") do
      internal_link(context, next, href)
    else
      external_link(context, next, href)
    end
  end

  def a(%Context{} = context, next, attrs) do
    {_error_id, _error_msg} =
      log_error("Malformed content element. Missing href attribute", attrs)

    external_link(context, next, "#")
  end

  defp internal_link(
         %Context{section_slug: section_slug, mode: mode, project_slug: project_slug},
         next,
         href
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

    [~s|<a class="internal-link" href="#{escape_xml!(href)}">|, next.(), "</a>\n"]
  end

  defp external_link(%Context{} = _context, next, href) do
    [~s|<a class="external-link" href="#{escape_xml!(href)}" target="_blank">|, next.(), "</a>\n"]
  end

  def cite(%Context{} = context, next, a) do
    bib_references = Map.get(context, :bib_app_params, [])
    bib_entry = Enum.find(bib_references, fn x -> x.id == Map.get(a, "bibref") end)

    if bib_entry != nil do
      [~s|<cite><sup>
      [<a onclick="var d=document.getElementById('#{bib_entry.slug}'); if (d &amp;&amp; d.scrollIntoView) d.scrollIntoView();return false;" href="##{bib_entry.slug}" class="ref">#{bib_entry.ordinal}</a>]
      </sup></cite>\n|]
    else
      ["<cite><sup>", next.(), "</sup></cite>\n"]
    end
  end

  def popup(%Context{} = context, next, %{"trigger" => trigger, "content" => content}) do
    trigger =
      if escape_xml!(trigger) == "hover" do
        "hover focus"
      else
        "manual"
      end

    [
      ~s"""
      <span
        tabindex="0"
        role="button"
        class="popup__anchorText#{if !String.contains?(trigger, "hover") do
        " popup__click"
      else
        ""
      end}"
        data-trigger="#{trigger}"
        data-toggle="popover"
        data-placement="top"
        data-html="true"
        data-template='
          <div class="popover popup__content" role="tooltip">
            <div class="arrow"></div>
            <h3 class="popover-header"></h3>
            <div class="popover-body"></div>
          </div>'
        data-content="#{escape_xml!(parse_html_content(content, context))}">
        #{next.()}
      </span>\n
      """
    ]
  end

  def selection(%Context{} = context, _, selection) do
    Oli.Rendering.Content.Selection.render(context, selection, true)
  end

  defp revision_slug_from_course_link(href) do
    href
    |> String.replace_prefix("/course/link/", "")
  end

  def definition(%Context{} = _context, next, _) do
    ["<extra>", next.(), "</extra>\n"]
  end

  def text(%Context{} = _context, %{"text" => text} = text_entity) do
    escape_xml!(text) |> wrap_with_marks(text_entity)
  end

  def error(%Context{} = _context, element, error) do
    case error do
      {:unsupported, error_id, _error_msg} ->
        [
          ~s|<div class="content unsupported">Content element type '#{element["type"]}' is not supported. Please contact support with issue ##{error_id}</div>\n|
        ]

      {:invalid, error_id, _error_msg} ->
        [
          ~s|<div class="content invalid">Content element is invalid. Please contact support with issue ##{error_id}</div>\n|
        ]

      {_, error_id, _error_msg} ->
        [
          ~s|<div class="content invalid">An error occurred while rendering content. Please contact support with issue ##{error_id}</div>\n|
        ]
    end
  end

  def example(%Context{} = _context, next, _) do
    [
      ~s|<div class="content-purpose example"><div class="content-purpose-label">Example</div><div class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def learn_more(%Context{} = _context, next, _) do
    [
      ~s|<div class="content-purpose learnmore"><div class="content-purpose-label">Learn more</div><div class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def manystudentswonder(%Context{} = _context, next, _) do
    [
      ~s|<div class="content-purpose manystudentswonder"><div class="content-purpose-label">Many Students Wonder</div><div class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def escape_xml!(text) do
    case HTML.html_escape(text) do
      {:safe, result} -> result
    end
  end

  defp wrap_with_marks(text, text_entity) do
    supported_mark_tags = %{
      "em" => "em",
      "strong" => "strong",
      "mark" => "mark",
      "del" => "del",
      "var" => "var",
      "code" => "code",
      "sub" => "sub",
      "sup" => "sup",
      "underline" => "underline",
      "strikethrough" => "strikethrough"
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
          "underline" -> ~s|<span style="text-decoration: underline;">#{acc}</span>|
          "strikethrough" -> ~s|<span style="text-decoration: line-through;">#{acc}</span>|
          _ -> "<#{mark}>#{acc}</#{mark}>"
        end
      end
    )
  end

  # Accessible captions are created using a combination of the <figure /> and <figcaption /> elements.
  defp figure(_context, %{"caption" => ""} = _attrs, content), do: content

  defp figure(%Context{} = context, %{"caption" => caption_content} = _attrs, content) do
    [~s|<div class="figure-wrapper">|] ++
      [~s|<figure class="figure embed-responsive text-center">|] ++
      content ++
      [~s|<figcaption class="figure-caption text-center">|] ++
      [caption(context, caption_content)] ++
      ["</figcaption>"] ++
      ["</figure>"] ++
      ["</div>"]
  end

  defp figure(_context, _attrs, content), do: content

  defp caption(_context, content) when is_binary(content) do
    escape_xml!(content)
  end

  defp caption(context, content) do
    Oli.Rendering.Content.render(context, content, __MODULE__)
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
      %{"alt" => alt} -> " alt=\"#{escape_xml!(alt)}\""
      _ -> ""
    end
  end

  defp maybeWidth(attrs) do
    case attrs do
      %{"width" => width} -> " width=\"#{escape_xml!(width)}\""
      _ -> ""
    end
  end
end
