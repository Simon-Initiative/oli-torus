defmodule OliWeb.ManualGrading.RenderedActivity do
  use OliWeb, :html

  attr :rendered_activity, :any, required: true
  attr :id, :string, default: nil

  def render(%{rendered_activity: nil} = assigns) do
    ~H"""
    <div />
    """
  end

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :rendered_activity,
        namespace_inner_ids(assigns.rendered_activity, assigns.id)
      )

    ~H"""
    <div class="mt-5 rendered-activity" id={@id} phx-hook="RenderedActivityIframeState">
      {raw(@rendered_activity)}
    </div>
    """
  end

  defp namespace_inner_ids(rendered_activity, id)
       when is_binary(rendered_activity) and is_binary(id) do
    marker = ~s(id="adaptive-screen-preview-)

    if String.contains?(rendered_activity, marker) do
      id = String.replace(id, ~r/[^A-Za-z0-9_-]/, "-")

      String.replace(
        rendered_activity,
        marker,
        ~s(id="#{id}-adaptive-screen-preview-)
      )
    else
      rendered_activity
    end
  end

  defp namespace_inner_ids(rendered_activity, _id), do: rendered_activity
end
