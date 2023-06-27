defmodule OliWeb.ErrorView do
  use OliWeb, :view

  # If you want to customize a particular status code
  # for a certain format, you may uncomment below.
  # def render("500.html", _assigns) do
  #   "Internal Server Error"
  # end

  # By default, Phoenix returns the status message from
  # the template name. For example, "404.html" becomes
  # "Not Found".
  # def template_not_found(_template, assigns) do
  #   Phoenix.Controller.status_message_from_template(template)
  # end

  def template_not_found(template, assigns) do
    case String.split(template, ".") do
      [_, "html"] -> render("http_status.html", assigns)
      _ -> Phoenix.Controller.status_message_from_template(template)
    end
  end

  def status_code(%{plug_status: plug_status}), do: plug_status
  def status_code(_), do: 500

  def status_message(reason) do
    status_code(reason)
    |> Plug.Conn.Status.reason_phrase()
  rescue
    _ -> "Internal Server Error"
  end

  def render_layout(layout, assigns, do: content) do
    render(layout, Map.put(assigns, :inner_content, content))
  end
end
