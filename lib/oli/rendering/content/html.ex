defmodule Oli.Rendering.Content.Html do
  @moduledoc """
  Implements the Html writer for Oli content rendering.

  Important: any changes to this file must be replicated in writers/html.ts for activity rendering.
  """
  alias Oli.Rendering.Context
  alias Phoenix.HTML

  @behaviour Oli.Rendering.Content

  def example(%Context{} = _context, next, _) do
    [~s|<div class="content-purpose example"><div class="content-purpose-label">Example</div><div class="content-purpose-content">|, next.(), "</div></div>\n"]
  end

  def learn_more(%Context{} = _context, next, _) do
    [~s|<div class="content-purpose learnmore"><div class="content-purpose-label">Learn more</div><div class="content-purpose-content">|, next.(), "</div></div>\n"]
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

  def img(%Context{} = _context, _, %{"src" => src} = attrs) do
    alt = case attrs do
      %{"alt" => alt} -> " alt=#{alt}"
      _ -> ""
    end

    # if attrs["caption"]
    figure(attrs, [~s|<img class="#{display_class(attrs)}"#{alt} src="#{src}"/>\n|])
    # else [~s|<img class="#{display_class(attrs)}"#{alt} src="#{src}"/>\n|]
    # end
  end

  def youtube(%Context{} = _context, _, %{"src" => src} = attrs) do
    # if attrs["caption"]
    # do
      figure(Map.put(attrs, "full-width", true), [
        """
        <div class="youtube-wrapper">
          <iframe id="#{src}" class="#{display_class(attrs)}" allowfullscreen src="https://www.youtube.com/embed/#{src}"></iframe>
        </div>
        """])
    # else
    #   [
    #     """
    #     <div class="youtube-wrapper #{display_class(attrs)}">
    #       <iframe id="#{src}" allowfullscreen src="https://www.youtube.com/embed/#{src}"></iframe>
    #     </div>
    #     """
    #   ]
    # end

  end

  def iframe(%Context{} = _context, _, %{"src" => src} = attrs) do
    figure(Map.put(attrs, "full-width", true), [
      """
      <div class="webpage-wrapper">
        <iframe class="#{display_class(attrs)}" allowfullscreen src="#{src}"></iframe>
      </div>
      """])
  end

  def audio(%Context{} = _context, _, %{"src" => src} = attrs) do
    figure(attrs, [~s|<audio controls src="#{src}">
      Your browser does not support the <code>audio</code> element.
    </audio>\n|])
  end

  def table(%Context{} = _context, next, attrs) do
    caption = case attrs do
      %{"caption" => caption} -> "<caption>#{caption}</caption>"
      _ -> ""
    end
    ["<table>#{caption}", next.(), "</table>\n"]
  end

  def tr(%Context{} = _context, next, _) do
    ["<tr>", next.(), "</tr>\n"]
  end

  def th(%Context{} = _context, next, _) do
    ["<th>", next.(), "</th>\n"]
  end

  def td(%Context{} = _context, next, _) do
    ["<td>", next.(), "</td>\n"]
  end

  def ol(%Context{} = _context, next, _) do
    ["<ol>", next.(), "</ol>\n"]
  end

  def ul(%Context{} = _context, next, _) do
    ["<ul>", next.(), "</ul>\n"]
  end

  def li(%Context{} = _context, next, _) do
    ["<li>", next.(), "</li>\n"]
  end

  def math(%Context{} = _context, next, _) do
    ["<div>\\[", next.(), "\\]</div>\n"]
  end

  def math_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  def code(%Context{} = _context, next, %{
    "language" => language,
  } = attrs) do
    figure(attrs, [~s|<pre><code class="language-#{language}">|, next.(), "</code></pre>\n"])
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

  defp internal_link(%Context{section_slug: section_slug}, next, href) do
    href = case section_slug do
      nil ->
        "#"

      section_slug ->
        # rewrite internal link using section slug and revision slug
        "/sections/#{section_slug}/page/#{revision_slug_from_course_link(href)}"
    end

    [~s|<a class="internal-link" href="#{escape_xml!(href)}">|, next.(), "</a>\n"]
  end

  defp external_link(%Context{} = _context, next, href) do
    [~s|<a class="external-link" href="#{escape_xml!(href)}" target="_blank">|, next.(), "</a>\n"]
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
        [~s|<div class="content unsupported">Content element type '#{element["type"]}' is not supported. Please contact support with issue ##{error_id}</div>\n|]
      {:invalid, error_id, _error_msg} ->
        [~s|<div class="content invalid">Content element is invalid. Please contact support with issue ##{error_id}</div>\n|]
      {_, error_id, _error_msg} ->
        [~s|<div class="content invalid">An error occurred while rendering content. Please contact support with issue ##{error_id}</div>\n|]
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
      "code" => "code",
      "sub" => "sub",
      "sup" => "sup",
    }
    marks = Map.keys(text_entity)
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
        "<#{mark}>#{acc}</#{mark}>"
      end
    )
  end

  # Accessible captions are created using a combination of the <figure /> and <figcaption /> elements.
  defp figure(%{"caption" => caption} = attrs, content) do
    [~s|<div class="figure-wrapper #{display_class(attrs)}">|]
      ++ ["<figure#{if attrs["full-width"] do " class=\"full-width\"" else "" end}>"]
        ++ content
        ++ ["<figcaption#{if attrs["full-width"] do " class=\"full-width\"" else "" end}>"]
          ++ [caption]
        ++ ["</figcaption>"]
      ++ ["</figure>"]
    ++ ["</div>"]
  end
  defp figure(_attrs, content), do: content

  defp display_class(%{"display" => display}), do: display_class(display)
  defp display_class(display) do
    case display do
      "float_left" -> "float-md-left"
      "float_right" -> "float-md-right"
      "block" -> "d-block"
      _ -> "d-block"
    end
  end
end
