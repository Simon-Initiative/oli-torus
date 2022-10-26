defmodule OliWeb.Common.CustomLabelsForm do
  use Surface.Component
  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, TextInput, Label}

  prop labels, :map, default: %{unit: "unit", module: "module", section: "section"}
  prop(save, :event, required: true)

  @spec render(any) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~F"""
      <Form for={:view} submit={@save} >
        {#for {k, v} <- @labels}
          <Field name={k} class="form-group">
            <Label text={k}/>
            <TextInput class="form-control" opts={placeholder: v}/>
          </Field>
        {/for}
        <button class="float-left btn btn-md btn-primary mt-2" type="submit">Save</button>
      </Form>
    """
  end

end
