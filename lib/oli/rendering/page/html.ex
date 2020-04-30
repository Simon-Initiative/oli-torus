defmodule Oli.Rendering.Page.Html do
  @moduledoc """
  Implements the Html writer for Oli page rendering
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content
  alias Oli.Rendering.Activity

  @behaviour Oli.Rendering.Page

  def content(%Context{} = context, element) do
    Content.render(context, element, Content.Html)
  end

  def activity(%Context{} = context, element) do
    Activity.render(context, element, Activity.Html)
  end

  def error(%Context{}, element, error) do
    case error do
      {:invalid_page_model, error_id, _error_msg} ->
        ["<div class=\"page invalid\">Page is invalid. Please contact support with issue ##{error_id}</div>\n"]
      {:unsupported, error_id, _error_msg} ->
        ["<div class=\"page-item unsupported\">Page item of type '", element["type"] ,"' is not supported. Please contact support with issue ##{error_id}</div>\n"]
      {_, error_id, _error_msg} ->
        ["<div class=\"page-item invalid\">An error occurred while rendering this page item. Please contact support with issue ##{error_id}</div>\n"]
    end
  end
end
