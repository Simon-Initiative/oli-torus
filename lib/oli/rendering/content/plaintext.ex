defmodule Oli.Rendering.Content.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for Oli content rendering.
  This was written quickly for simplicity. It leaves a trailing space at the end of the final string.
  """
  alias Oli.Rendering.Context

  @behaviour Oli.Rendering.Content

  def example(%Context{} = _context, next, _) do
    ["[Example]: ", next.(), " "]
  end

  def learn_more(%Context{} = _context, next, _) do
    ["[Learn more]: ", next.(), " "]
  end

  def p(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h1(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h2(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h3(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h4(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h5(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def h6(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def img(%Context{} = _context, _, %{"src" => src}) do
    ["[image with src #{src}] "]
  end

  def youtube(%Context{} = _context, _, %{"src" => src}) do
    ["[youtube with src #{src}] "]
  end

  def audio(%Context{} = _context, _, %{"src" => src}) do
    ["[audio with src #{src} "]
  end

  def table(%Context{} = _context, next, _) do
    [next.()]
  end

  def tr(%Context{} = _context, next, _) do
    [next.()]
  end

  def th(%Context{} = _context, next, _) do
    [next.()]
  end

  def td(%Context{} = _context, next, _) do
    [next.()]
  end

  def ol(%Context{} = _context, next, _) do
    [next.()]
  end

  def ul(%Context{} = _context, next, _) do
    [next.()]
  end

  def li(%Context{} = _context, next, _) do
    ["[List item]: ", next.(), " "]
  end

  def math(%Context{} = _context, next, _) do
    ["[Math]: ", next.(), " "]
  end

  def math_line(%Context{} = _context, next, _) do
    [next.()]
  end

  def code(%Context{} = _context, next, %{
    "language" => _language,
  }) do
    ["[Code]: ", next.(), " "]
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def blockquote(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def a(%Context{} = _context, next, %{"href" => href}) do
    ["[link to #{href}", next.(), " "]
  end

  def definition(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def text(%Context{} = _context, %{"text" => text}) do
    text
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
end
