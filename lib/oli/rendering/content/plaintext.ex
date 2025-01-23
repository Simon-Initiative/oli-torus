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

  def content(%Context{} = _context, next, _) do
    next.()
  end

  def trigger(%Context{} = context, _, attrs) do
    [""]
  end

  def manystudentswonder(%Context{} = _context, next, _) do
    ["[Many students wonder]: ", next.(), " "]
  end

  def callout(%Oli.Rendering.Context{} = _context, next, _) do
    [next.(), " "]
  end

  def callout_inline(%Oli.Rendering.Context{} = _context, next, _) do
    [next.(), " "]
  end

  def p(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def input_ref(%Context{} = _context, _next, _) do
    ["[user input]"]
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

  def dl(%Context{}, next, title, %{}) do
    [
      title.(),
      "\n",
      next.()
    ]
  end

  def dt(%Context{}, next, %{}) do
    [next.(), "\n"]
  end

  def dd(%Context{}, next, %{}) do
    [next.(), "\n"]
  end

  def ecl(%Context{} = _context, _, _attrs) do
    ["[ecl]"]
  end

  def img(%Context{} = _context, _, %{"src" => src}) do
    ["[image with src #{src}] "]
  end

  def img(%Context{} = _context, _, _) do
    ["[image with missing src] "]
  end

  def img_inline(%Context{} = _context, _, %{"src" => src}) do
    ["[image with src #{src}] "]
  end

  def img_inline(%Context{} = _context, _, _) do
    ["[image with missing src] "]
  end

  def video(%Context{} = _context, _, _) do
    ["[video]"]
  end

  def youtube(%Context{} = _context, _, %{"src" => src}) do
    ["[youtube with src #{src}] "]
  end

  def youtube(%Context{} = _context, _, _) do
    ["[youtube with missing src] "]
  end

  def iframe(%Context{} = _context, _, %{"src" => src}) do
    ["[iframe with src #{src}] "]
  end

  def iframe(%Context{} = _context, _, _) do
    ["[iframe with missing src] "]
  end

  def audio(%Context{} = _context, _, %{"src" => src}) do
    ["[audio with src #{src}] "]
  end

  def audio(%Context{} = _context, _, _) do
    ["[audio with missing src] "]
  end

  def command_button(%Context{} = _context, next, _attrs) do
    [next.()]
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

  def tc(%Context{} = _context, next, _) do
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

  def formula(%Oli.Rendering.Context{} = _context, nil, %{"src" => src}) do
    ["[Formula]: ", src, " "]
  end

  def formula(%Oli.Rendering.Context{} = _context, next, _) do
    ["[Formula]: ", next.(), " "]
  end

  def formula_inline(context, next, content) do
    formula(context, next, content)
  end

  def math(%Context{} = _context, next, _) do
    ["[Math]: ", next.(), " "]
  end

  def math_line(%Context{} = _context, next, _) do
    [next.()]
  end

  def code(%Context{} = _context, next, _) do
    ["[Code]: ", next.(), " "]
  end

  def code_line(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def blockquote(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def a(%Context{} = _context, next, %{"href" => href}) do
    ["[link to #{href} ", next.(), " "]
  end

  def a(%Context{} = _context, next, _) do
    ["[link with missing href ", next.(), " "]
  end

  def cite(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def figure(%Context{} = _context, render_children, render_title, _) do
    [render_title.(), "\n", render_children.(), "\n"]
  end

  def foreign(_context, next, _attrs) do
    [
      next.()
    ]
  end

  def conjugation(%Oli.Rendering.Context{}, render_table, render_pronunciation, attrs) do
    [
      attrs["title"],
      render_pronunciation.(),
      render_table.()
    ]
  end

  def definition_meaning(%Context{} = _context, next, _) do
    ["  ", next.(), "\n"]
  end

  def definition_translation(%Context{} = _context, next, _) do
    ["  Translation: ", next.(), "\n"]
  end

  def pronunciation(%Context{} = _context, next, _) do
    ["  Pronunciation: ", next.(), "\n"]
  end

  def definition(
        %Context{} = _context,
        render_translation,
        render_pronunciation,
        render_meaning,
        %{"term" => term}
      ) do
    [
      "Definition: ",
      term,
      "\n",
      render_meaning.(),
      render_pronunciation.(),
      render_translation.(),
      "\n"
    ]
  end

  def popup(%Context{} = _context, next, _) do
    ["[popup with text ", next.(), "]"]
  end

  def definition(%Context{} = _context, next, _) do
    [next.(), " "]
  end

  def dialog(%Context{} = _context, next, %{"title" => title}) do
    ["Dialog: ", title, "\n", next.(), " "]
  end

  def dialog(%Context{} = _context, next, _) do
    ["Dialog:\n", next.(), " "]
  end

  def dialog_line(%Context{}, next, %{"speaker" => speaker_id}, %{"speakers" => speakers}) do
    speaker = Enum.find(speakers, fn speaker -> speaker["id"] == speaker_id end)

    case speaker do
      nil ->
        [
          "Unknown: ",
          next.(),
          "\n"
        ]

      _ ->
        [
          speaker["name"],
          ": ",
          next.(),
          "\n"
        ]
    end
  end

  def dialog_line(%Context{}, next, _, _) do
    [
      "Unknown: ",
      next.(),
      "\n"
    ]
  end

  def text(%Context{} = _context, %{"text" => text}) do
    text
  end

  def selection(%Context{} = _context, _, _selection) do
    ["[Activity Bank Selection]"]
  end

  def page_link(%Context{} = _context, _, %{"title" => title, "ref" => ref, "purpose" => purpose}) do
    ["[Page Link: \"#{title}\" ref=\"#{ref}\" purpose=\"#{purpose}\"]"]
  end

  def error(%Context{} = _context, element, error) do
    case error do
      {:unsupported, error_id, _error_msg} ->
        [
          "<div class=\"content unsupported\">Content element type '",
          element["type"],
          "' is not supported. Please contact support with issue ##{error_id}</div>\n"
        ]

      {:invalid, error_id, _error_msg} ->
        [
          "<div class=\"content invalid\">Content element is invalid. Please contact support with issue ##{error_id}</div>\n"
        ]

      {_, error_id, _error_msg} ->
        [
          "<div class=\"content invalid\">An error occurred while rendering content . Please contact support with issue ##{error_id}</div>\n"
        ]
    end
  end
end
