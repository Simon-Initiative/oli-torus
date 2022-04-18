defmodule Oli.Rendering.Group.Html do
  @moduledoc """
  Implements the Html writer for content group rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Utils.Purposes

  @behaviour Oli.Rendering.Group

  def group(%Context{} = _context, next, %{"purpose" => purpose}) do
    [
      ~s|<div class="group content-purpose #{purpose}"><div class="content-purpose-label">#{Purposes.label_for(purpose)}</div><div class="content-purpose-content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def error(%Context{}, _group, error) do
    case error do
      {:invalid, error_id, _error_msg} ->
        [
          "<div class=\"group invalid alert alert-danger\">Rendering error. Please contact support with issue <strong>##{error_id}</strong></div>\n"
        ]

      {_, error_id, _error_msg} ->
        [
          "<div class=\"group error alert alert-danger\">An error occurred and this content could not be shown. Please contact support with issue <strong>##{error_id}</strong></div>\n"
        ]
    end
  end
end
