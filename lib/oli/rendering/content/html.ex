defmodule Oli.Rendering.Content.Html do
  @moduledoc """
  Implements the Html writer for Oli content rendering.

  Important: any changes to this file must be replicated in writers/html.ts for activity rendering.
  """

  use OliWeb, :verified_routes

  import Oli.Utils
  import Oli.Rendering.Utils

  require Logger

  alias Oli.Rendering.Context
  alias Phoenix.HTML
  alias Oli.Rendering.Content.MathMLSanitizer
  alias HtmlSanitizeEx.Scrubber
  alias Oli.Utils.Purposes
  alias Oli.Rendering.Content.ResourceSummary

  @behaviour Oli.Rendering.Content

  def callout(%Oli.Rendering.Context{} = _context, next, _) do
    ["<span class=\"callout-block\">", next.(), "</span>\n"]
  end

  def callout_inline(%Oli.Rendering.Context{} = _context, next, _) do
    ["<span class=\"callout-inline\">", next.(), "</span>\n"]
  end

  def p(%Context{} = context, next, attrs) do
    ["<p", maybe_point_marker_attr(context, attrs), ">", next.(), "</p>\n"]
  end

  def input_ref(%Context{} = _context, next, _) do
    ["<span>", next.(), "</span>\n"]
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
    captioned_content(
      context,
      attrs,
      [
        ~s|<img class="figure-img img-fluid"#{maybe_alt(attrs)}#{maybe_width(attrs)} src="#{escape_xml!(src)}"|,
        maybe_point_marker_attr(context, attrs),
        ~s| />\n|
      ],
      "image"
    )
  end

  def img(%Context{} = _context, _, _e), do: ""

  def img_inline(%Context{} = _context, _, %{"src" => src} = attrs) do
    [
      ~s|<img class="img-fluid"#{maybe_alt(attrs)}#{maybe_width(attrs)} src="#{escape_xml!(src)}"/>\n|
    ]
  end

  def img_inline(%Context{} = _context, _, _e), do: ""

  def video(%Context{} = context, _, attrs) do
    attempt_guid =
      case context.resource_attempt do
        nil -> ""
        attempt -> attempt.attempt_guid
      end

    {:safe, video_player} =
      OliWeb.Common.React.component(context, "Components.VideoPlayer", %{
        "video" => attrs,
        "pageAttemptGuid" => attempt_guid,
        "pointMarkerContext" => %{
          renderPointMarkers: context.render_opts.render_point_markers,
          isAnnotationLevel: context.is_annotation_level
        }
      })

    video_player
  end

  def ecl(%Context{} = context, _, attrs) do
    attempt_guid =
      case context.resource_attempt do
        nil -> ""
        attempt -> attempt.attempt_guid
      end

    {:safe, ecl} =
      OliWeb.Common.React.component(
        context,
        "Components.ECLRepl",
        %{
          "code" => attrs["code"],
          "id" => attrs["id"],
          "slug" => context.section_slug,
          "attemptGuid" => attempt_guid,
          "pointMarkerContext" => %{
            renderPointMarkers: context.render_opts.render_point_markers,
            isAnnotationLevel: context.is_annotation_level
          }
        }
      )

    ecl
  end

  def youtube(%Context{} = context, _, %{"src" => _} = attrs) do
    {:safe, video_player} =
      OliWeb.Common.React.component(context, "Components.YoutubePlayer", %{
        "video" => attrs,
        "pointMarkerContext" => %{
          renderPointMarkers: context.render_opts.render_point_markers,
          isAnnotationLevel: context.is_annotation_level
        }
      })

    video_player
  end

  def youtube(%Context{} = _context, _, _e), do: ""

  def iframe(%Context{} = context, _, %{"src" => src} = attrs) do
    has_width = not is_nil(attrs["width"])
    has_height = not is_nil(attrs["height"])

    dimensions =
      cond do
        has_width and has_height ->
          # Both dimensions specified
          " width=\"#{attrs["width"]}\" height=\"#{attrs["height"]}\" "

        has_width ->
          # Width with no height, default to a square size
          " width=\"#{attrs["width"]}\" height=\"#{attrs["width"]}\" "

        true ->
          ""
      end

    # With no dimensions set, we rely on the responsive CSS classes to set dimensions
    iframe_class =
      if has_width do
        "mx-auto"
      else
        "embed-responsive-item"
      end

    container_class =
      if has_width do
        ""
      else
        "embed-responsive embed-responsive-16by9"
      end

    captioned_content(context, attrs, [
      """
      <div class="#{container_class}">
        <div class="embed-wrapper">
          <iframe#{maybe_alt(attrs)} class="#{iframe_class}" #{dimensions} allowfullscreen src="#{escape_xml!(src)}"#{maybe_point_marker_attr(context, attrs)}></iframe>
        </div>
      </div>
      """
    ])
  end

  def iframe(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  def audio(%Context{} = context, _, %{"src" => src} = attrs) do
    captioned_content(context, attrs, [
      ~s|<audio aria-label="#{attrs["alt"]}" controls src="#{escape_xml!(src)}"#{maybe_point_marker_attr(context, attrs)}>
      Your browser does not support the <code>audio</code> element.
    </audio>\n|
    ])
  end

  def audio(%Context{} = context, _, e) do
    missing_media_src(context, e)
  end

  defp tableBorderClass(%{"border" => "hidden"}), do: "table-borderless"
  defp tableBorderClass(_), do: "table-bordered"

  defp tableRowClass(%{"rowstyle" => "alternating"}), do: "table-striped"
  defp tableRowClass(_), do: ""

  def table(%Context{} = context, next, attrs) do
    # We want to ensure that tables are always wrapped
    # in a figure element, even if there is no caption. When
    # a caption attr is present but "empty" we still want the figure,
    # but not an empty <figcaption>.  The <figure> element with its
    # responsive-embed class is needed in all cases to acheive correct
    # table display.

    wrapping_fn =
      case attrs do
        %{"caption" => ""} -> &figure_only/3
        %{"caption" => nil} -> &figure_only/3
        %{"caption" => [%{"children" => [%{"text" => ""}], "type" => "p"}]} -> &figure_only/3
        %{"caption" => _an_actual_caption} -> &captioned_content/3
        _ -> &figure_only/3
      end

    wrapping_fn.(context, attrs, [
      "<table class='#{tableBorderClass(attrs)} #{tableRowClass(attrs)}'#{maybe_point_marker_attr(context, attrs)}>",
      next.(),
      "</table>\n"
    ])
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

  def tc(%Context{} = _context, next, attrs) do
    [click_class, audio_element, play_code, _] =
      case attrs["audioSrc"] do
        nil -> ["", "", "", ""]
        src -> ["clickable" | audio_player(src)]
      end

    pronouns =
      case attrs["pronouns"] do
        nil -> []
        pronouns -> ["<i>", pronouns, "</i> "]
      end

    [
      "<td#{maybeAlign(attrs)} class=\"conjugation-cell #{click_class}\" onClick=#{play_code}>",
      pronouns,
      next.(),
      audio_element,
      "</td>\n"
    ]
  end

  def ol(%Context{} = _context, next, %{"style" => style}) do
    ["<ol class=\"list-#{style} list-inside pl-2\">", next.(), "</ol>\n"]
  end

  def ol(%Context{} = _context, next, _) do
    ["<ol class=\"list-inside pl-2\">", next.(), "</ol>\n"]
  end

  def dl(%Context{}, next, title, %{}) do
    [
      "<h4 class=\"dl-title\">",
      title.(),
      "</h4>\n",
      "<dl>",
      next.(),
      "</dl>\n"
    ]
  end

  def dt(%Context{}, next, %{}) do
    ["<dt>", next.(), "</dt>\n"]
  end

  def dd(%Context{}, next, %{}) do
    ["<dd>", next.(), "</dd>\n"]
  end

  def ul(%Context{} = _context, next, %{"style" => style}) do
    ["<ul class=\"list-#{style} list-inside pl-2\">", next.(), "</ul>\n"]
  end

  def ul(%Context{} = _context, next, _) do
    ["<ul class=\"list-inside pl-2\">", next.(), "</ul>\n"]
  end

  def li(%Context{} = context, next, attrs) do
    ["<li#{maybe_point_marker_attr(context, attrs)}>", next.(), "</li>\n"]
  end

  def conjugation(%Context{} = context, render_table, render_pronunciation, attrs) do
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

    [
      "<div class=\"conjugation\"",
      maybe_point_marker_attr(context, attrs),
      ">",
      "<div class=\"title\">",
      title,
      "</div>",
      "<div class=\"term\">",
      verb,
      render_pronunciation.(),
      "</div>",
      render_table.(),
      "</div>"
    ]
  end

  def dialog(%Context{} = context, next, %{"title" => title} = attrs) do
    [
      "<div class=\"dialog\"",
      maybe_point_marker_attr(context, attrs),
      "><h1>",
      title,
      "</h1>",
      next.(),
      "</div>"
    ]
  end

  def dialog(%Context{} = context, next, attrs) do
    ["<div class=\"dialog\"", maybe_point_marker_attr(context, attrs), ">", next.(), "</div>"]
  end

  def dialog_speaker_portrait(image) do
    "<img src=\"#{image}\" class=\"img-fluid speaker-portrait\"/>"
  end

  def dialog_speaker_portrait() do
    ~s|<i class="fa-solid fa-image-portrait"></i>|
  end

  def dialog_speaker(speaker_id, %{"speakers" => speakers}) do
    speaker = Enum.find(speakers, fn speaker -> speaker["id"] == speaker_id end)

    ["<div class=\"dialog-speaker\" >"] ++
      case speaker do
        %{"name" => name, "image" => image} ->
          [dialog_speaker_portrait(image), "<div class=\"speaker-name\">", name, "</div>"]

        %{"name" => name} ->
          [dialog_speaker_portrait(), "<div class=\"speaker-name\">", name, "</div>"]

        _ ->
          ["<div class=\"speaker-name\">", "Unknown Speaker", "</div>"]
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
      "<div class=\"dialog-line #{dialog_line_class(speaker_id, dialog)}\">",
      dialog_speaker(speaker_id, dialog),
      "<div class=\"dialog-content\">",
      next.(),
      "</div></div>"
    ]
  end

  def definition_meaning(%Context{} = _context, next, _) do
    ["<li class='meaning'>", next.(), "</li>\n"]
  end

  def definition_translation(%Context{} = _context, next, _) do
    ["<span class='translation'>", next.(), " </span>\n"]
  end

  defp audio_player(nil), do: ["", "", ""]

  defp audio_player(src) do
    audio_id = UUID.uuid4()
    # See app.ts for toggleAudio()
    play_code = "window.toggleAudio(document.getElementById(\"#{audio_id}\"));"
    audio_element = "<audio id='#{audio_id}' src='#{escape_xml!(src)}' preload='auto'></audio>"
    [audio_element, play_code, audio_id]
  end

  def pronunciation(%Context{} = _context, next, element) do
    case element["src"] do
      nil ->
        ["<span class='pronunciation'>", next.(), "</span>\n"]

      src ->
        [audio_element, play_code, _] = audio_player(src)

        [
          "<span class='pronunciation'>",
          ~s|<span class='play-button' onClick='#{play_code}'><i class="fa-solid fa-circle-play"></i></span>|,
          "<span class='pronunciation-player' onClick='#{play_code}'>",
          audio_element,
          next.(),
          "</span></span>\n"
        ]
    end
  end

  defp maybePronunciationHeader(%{"pronunciation" => pronunciation}) do
    if Oli.Activities.ParseUtils.has_content?(pronunciation) do
      "Pronunciation: "
    else
      ""
    end
  end

  defp maybePronunciationHeader(_), do: ""

  defp meaningClass(meanings) do
    case Enum.count(meanings) do
      0 -> "meanings-empty"
      1 -> "meanings-single"
      _ -> "meanings"
    end
  end

  def definition(
        %Context{} = context,
        render_translation,
        render_pronunciation,
        render_meaning,
        %{"term" => term, "meanings" => meanings} = element
      ) do
    [
      "<div class='definition'",
      maybe_point_marker_attr(context, element),
      "><div class='term'>",
      term,
      "</div><i>(definition)</i> <span class='definition-header'>",
      maybePronunciationHeader(element),
      render_pronunciation.(),
      "<span class='definition-pronunciation'>",
      render_translation.(),
      "</span></span><ol class='#{meaningClass(meanings)}'>",
      render_meaning.(),
      "</ol></div>\n"
    ]
  end

  def foreign(
        %Oli.Rendering.Context{learning_language: learning_language},
        next,
        attrs
      ) do
    [
      "<span class='foreign' lang='#{attrs["lang"] || learning_language}'>",
      next.(),
      "</span>"
    ]
  end

  def formula_class(false), do: "formula"
  def formula_class(true), do: "formula-inline"

  def formula(context, next, properties, inline \\ false)

  def formula(context, next, %{"legacyBlockRendered" => true} = properties, _inline) do
    formula(context, next, Map.delete(properties, "legacyBlockRendered"), false)
  end

  def formula(
        %Oli.Rendering.Context{} = _context,
        _next,
        %{"subtype" => "latex", "src" => src},
        true
      ) do
    ["<span class=\"#{formula_class(true)}\">\\(", escape_xml!(fix_nl(src)), "\\)</span>\n"]
  end

  def formula(
        %Oli.Rendering.Context{} = context,
        _next,
        %{"subtype" => "latex", "src" => src} = attrs,
        false
      ) do
    [
      "<span class=\"#{formula_class(false)}\"#{maybe_point_marker_attr(context, attrs)}>\\[",
      escape_xml!(fix_nl(src)),
      "\\]</span>\n"
    ]
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

  # workaround lack of support in MathJax 3.0 for LaTeX newline \\
  def fix_nl(src) do
    if String.match?(src, ~r/\\\\./) and
         not (String.starts_with?(src, "\\displaylines") or
                String.starts_with?(src, "\\begin{array}")),
       do: "\\displaylines{#{src}}",
       else: src
  end

  def figure(%Context{} = context, render_children, render_title, el) do
    [
      "<div class='figure'",
      maybe_point_marker_attr(context, el),
      "><figure><figcaption>",
      render_title.(),
      "</figcaption><div class='figure-content'>",
      render_children.(),
      "</div></figure></div>\n"
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

    captioned_content(context, attrs, [
      ~s|<pre><code class="torus-code language-#{language}"#{maybe_point_marker_attr(context, attrs)}>#{escape_xml!(code)}</code></pre>\n|
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

    captioned_content(context, attrs, [
      ~s|<pre><code class="torus-code language-#{language}"#{maybe_point_marker_attr(context, attrs)}>|,
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

    captioned_content(context, attrs, [
      ~s|<pre><code class="torus-code language-none">|,
      next.(),
      "</code></pre>\n"
    ])
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  def command_button(%Context{} = _context, next, %{
        "style" => style,
        "target" => target,
        "message" => message
      }) do
    css_class =
      case style do
        "link" -> "btn btn-link command-button"
        _ -> "btn btn-primary command-button"
      end

    [
      "<span class=\"#{css_class}\" data-action=\"command-button\" data-target=\"#{escape_xml!(target)}\" data-message=\"#{message}\">",
      next.(),
      "</span>"
    ]
  end

  def command_button(%Context{} = _context, next, %{
        "target" => target,
        "message" => message
      }) do
    [
      "<span class=\"btn btn-primary command-button\" data-action=\"command-button\" data-target=\"#{escape_xml!(target)}\" data-message=\"#{message}\">",
      next.(),
      "</span>"
    ]
  end

  def command_button(%Context{} = _context, next, _attrs) do
    [next.()]
  end

  def blockquote(%Context{} = context, next, attrs) do
    ["<blockquote", maybe_point_marker_attr(context, attrs), ">", next.(), "</blockquote>\n"]
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
         %Context{section_slug: section_slug, mode: mode, project_slug: project_slug} = context,
         next,
         href,
         opts \\ []
       ) do
    href =
      cond do
        section_slug in [nil, project_slug] ->
          case mode do
            :author_preview ->
              "/authoring/project/#{project_slug}/preview/#{revision_slug_from_course_link(href)}"

            _ ->
              "#"
          end

        section_slug != project_slug ->
          # rewrite internal link using section slug and revision slug
          case mode do
            :instructor_preview ->
              "/sections/#{section_slug}/preview/page/#{revision_slug_from_course_link(href)}"

            _ ->
              ~p"/sections/#{section_slug}/lesson/#{revision_slug_from_course_link(href)}?#{context.page_link_params}"
          end
      end

    target_rel =
      case Keyword.get(opts, :target) do
        nil -> ""
        target -> ~s| target="#{target}" rel="noreferrer"|
      end

    [~s|<a class="internal-link" href="#{escape_xml!(href)}"#{target_rel}>|, next.(), "</a>\n"]
  end

  defp external_link(%Context{} = _context, next, href) do
    [
      ~s|<a class="external-link" href="#{escape_xml!(href)}" target="_blank" rel="noreferrer">|,
      next.(),
      "</a>\n"
    ]
  end

  def page_link(
        %Context{resource_summary_fn: resource_summary_fn} = context,
        _next,
        %{
          "idref" => idref,
          "purpose" => purpose
        } = attrs
      ) do
    %ResourceSummary{title: title, slug: slug} = resource_summary_fn.(idref)
    href = "/course/link/#{slug}"

    [
      ~s|<div class="content-page-link content-purpose #{purpose}"#{maybe_point_marker_attr(context, attrs)}><div class="content-purpose-label">#{Purposes.label_for(purpose)}</div>|,
      internal_link(
        context,
        fn ->
          [
            ~s|<div class="content-purpose-content d-flex flex-row">|,
            ~s|<div class="title flex-grow-1">|,
            escape_xml!(title),
            "</div>",
            ~s|<i class="fas fa-external-link-square-alt la-2x self-center"></i>|,
            "</div>\n"
          ]
        end,
        href,
        target: "_blank"
      ),
      "</div>"
    ]
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

  def popup(%Context{} = context, _next, element) do
    {:safe, rendered} =
      OliWeb.Common.React.component(
        context,
        "Components.DeliveryElementRenderer",
        %{
          "element" => element,
          "inline" => true
        },
        html_element: "span",
        container_tag: :span,
        receiver_tag: :span,
        id: "popup_#{UUID.uuid4()}"
      )

    rendered
  end

  def selection(%Context{} = context, _, selection) do
    Oli.Rendering.Content.Selection.render(context, selection, true)
  end

  defp revision_slug_from_course_link(href) do
    href
    |> String.replace_prefix("/course/link/", "")
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

  def example(%Context{} = _context, next, element) do
    [
      ~s|<div class="content-purpose example"><div class="content-purpose-label">Example</div><div #{direction_attr(element)} class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def learn_more(%Context{} = _context, next, element) do
    [
      ~s|<div class="content-purpose learnmore"><div class="content-purpose-label">Learn more</div><div #{direction_attr(element)} class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def manystudentswonder(%Context{} = _context, next, element) do
    [
      ~s|<div class="content-purpose manystudentswonder"><div class="content-purpose-label">Many Students Wonder</div><div #{direction_attr(element)} class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def content(%Context{} = _context, next, element) do
    [
      ~s|<div class="content" #{direction_attr(element)}>|,
      next.(),
      "</div>"
    ]
  end

  defp direction_attr(element) do
    case Map.get(element, "textDirection", "ltr") do
      "ltr" -> ""
      "rtl" -> " dir=\"rtl\""
      _ -> ""
    end
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
      "term" => "term",
      "code" => "code",
      "sub" => "sub",
      "doublesub" => "doublesub",
      "deemphasis" => "deemphasis",
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
          "term" -> ~s|<span class="term">#{acc}</span>|
          "underline" -> ~s|<span style="text-decoration: underline;">#{acc}</span>|
          "strikethrough" -> ~s|<span style="text-decoration: line-through;">#{acc}</span>|
          "doublesub" -> ~s|<sub><sub>#{acc}</sub></sub>|
          "deemphasis" -> ~s|<em class="deemphasis">#{acc}</em>|
          _ -> "<#{mark}>#{acc}</#{mark}>"
        end
      end
    )
  end

  defp maybe_content_type(content_type) do
    if content_type != "" do
      " caption-wrapper-#{content_type}"
    else
      ""
    end
  end

  defp captioned_content(context, attrs, content, content_type \\ "")

  # Accessible captions are created using a combination of the <figure /> and <figcaption /> elements.
  defp captioned_content(_context, %{"caption" => ""} = _attrs, content, _content_type),
    do: content

  defp captioned_content(
         %Context{} = context,
         %{"caption" => caption_content} = _attrs,
         content,
         content_type
       ) do
    [~s|<div class="caption-wrapper#{maybe_content_type(content_type)}">|] ++
      [~s|<figure class="figure embed-responsive">|] ++
      content ++
      [~s|<figcaption class="figure-caption text-center">|] ++
      [caption(context, caption_content)] ++
      ["</figcaption>"] ++
      ["</figure>"] ++
      ["</div>"]
  end

  defp captioned_content(_context, _attrs, content, _content_type), do: content

  defp caption(_context, content) when is_binary(content) do
    escape_xml!(content)
  end

  defp caption(context, content) do
    Oli.Rendering.Content.render(context, content, __MODULE__)
  end

  defp figure_only(_context, _attrs, content) do
    [
      ~s|<figure class="figure embed-responsive">|,
      ~s|<div class="figure-content">|,
      content,
      "</div>",
      "</figure>"
    ]
  end

  defp missing_media_src(%Context{render_opts: render_opts} = context, element) do
    {error_id, error_msg} = log_error("Malformed content element. Missing src attribute", element)

    if render_opts.render_errors do
      error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end

  defp maybe_alt(attrs) do
    case attrs do
      %{"alt" => alt} -> " alt=\"#{escape_xml!(alt)}\""
      _ -> ""
    end
  end

  defp maybe_width(attrs) do
    case attrs do
      %{"width" => width} -> " width=\"#{escape_xml!(width)}\""
      _ -> ""
    end
  end

  defp maybe_point_marker_attr(%Context{is_annotation_level: true} = context, %{"id" => id}) do
    if context.render_opts.render_point_markers do
      " data-point-marker=\"#{id}\""
    else
      ""
    end
  end

  defp maybe_point_marker_attr(%Context{is_annotation_level: true} = context, attrs) do
    if context.render_opts.render_point_markers do
      Logger.warning(
        "Content element missing id attribute which is required for point marker. Point marker will not be rendered.\n" <>
          Jason.encode!(attrs)
      )
    end

    ""
  end

  defp maybe_point_marker_attr(_context, _attrs), do: ""
end
