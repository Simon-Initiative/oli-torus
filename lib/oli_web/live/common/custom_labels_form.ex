defmodule OliWeb.Common.CustomLabelsForm do
  use OliWeb, :html

  attr(:labels, :map, default: %{unit: "Unit", module: "Module", section: "Section"})
  attr(:save, :any, required: true)

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    IO.inspect(assigns.labels, label: "labels!")

    ~H"""
    <.form for={:view} phx-submit={@save}>
      <%= for {k, v} <- @labels do %>
        <div class="form-group">
          <.input class="form-control" placeholder={v} value={v} name={k} label={humanize(k)} />
        </div>
      <% end %>
      <button class="float-left btn btn-md btn-primary mt-2" type="submit">Save</button>
    </.form>
    """
  end
end
