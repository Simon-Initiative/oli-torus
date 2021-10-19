defmodule OliWeb.Sections.MainDetails do
  use Surface.Component

  alias Surface.Components.{Form, Field}
  alias Surface.Components.Form.{Field, Label, TextInput}
  import OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Changeset

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true

  def render(assigns) do
    ~F"""
    <div>
      <Field name={:title}>
        <Label/>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:description}>
        <Label/>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <button class="btn btn-primary" type="submit">Save</button>
    </div>
    """
  end
end
