defmodule Oli.Rendering.Content.Html do
  @moduledoc """
  Implements the Html writer for Oli content rendering
  """
  alias Oli.Rendering.Context
  alias Phoenix.HTML

  @behaviour Oli.Rendering.Content

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

    height_width = case attrs do
      %{"height" => height, "width" => width} -> ["height=#{height} width=#{width}"]
      _ -> []
    end

    ["<img "]
    ++ height_width
    ++ [" style=\"display: block; max-height: 500px; margin-left: auto; margin-right: auto;\" src=\"", src, "\"/>\n"]
  end

  def youtube(%Context{} = _context, _, %{"src" => src}) do
    ["""
    <iframe
      id="#{src}"
      width="640"
      height="476"
      src="https://www.youtube.com/embed/#{src}"
      frameBorder="0"
      style="display: block; margin-left: auto; margin-right: auto;"
    ></iframe>
    """]
  end

  def audio(%Context{} = _context, _, %{"src" => src}) do
    ["<audio src=\"", src, "\"/>\n"]
  end

  def table(%Context{} = _context, next, _) do
    ["<table>", next.(), "</table>\n"]
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
    "language" => _language,
    "startingLineNumber" => _startingLineNumber,
    "showNumbers" => _showNumbers
  }) do
    ["<pre><code>", next.(), "</pre></code>\n"]
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), "\n"]
  end

  def blockquote(%Context{} = _context, next, _) do
    ["<blockquote>", next.(), "</blockquote>\n"]
  end

  def a(%Context{} = _context, next, %{"href" => href}) do
    ["<a href=\"#{escape_xml!(href)}\">", next.(), "</a>\n"]
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
        ["<div class=\"content unsupported\">Content element type '", element["type"] ,"' is not supported. Please contact support with issue ##{error_id}</div>\n"]
      {:invalid, error_id, _error_msg} ->
        ["<div class=\"content invalid\">Content element is invalid. Please contact support with issue ##{error_id}</div>\n"]
      {_, error_id, _error_msg} ->
        ["<div class=\"content invalid\">An error occurred while rendering content . Please contact support with issue ##{error_id}</div>\n"]
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
end
