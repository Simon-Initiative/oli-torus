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

  # Two copies of one rendered activity on a page would repeat its own ids; each copy prefixes
  # them with its component id. `Html.activity` returns iodata, adaptive previews a string.
  defp namespace_inner_ids(rendered_activity, id)
       when is_binary(id) and (is_binary(rendered_activity) or is_list(rendered_activity)) do
    id = String.replace(id, ~r/[^A-Za-z0-9_-]/, "-")

    Enum.reduce(
      ["jump-question-", "adaptive-screen-preview-"],
      IO.iodata_to_binary(rendered_activity),
      &String.replace(&2, ~s(id="#{&1}), ~s(id="#{id}-#{&1}))
    )
  end

  defp namespace_inner_ids(rendered_activity, _id), do: rendered_activity
end
