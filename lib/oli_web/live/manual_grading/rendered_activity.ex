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
    String.replace(
      rendered_activity,
      ~s(id="adaptive-screen-preview-),
      ~s(id="#{id}-adaptive-screen-preview-)
    )
  end

  defp namespace_inner_ids(rendered_activity, _id), do: rendered_activity
end
