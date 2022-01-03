defmodule OliWeb.CommunityLive.Invitation do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, TextInput}

  prop list_id, :string, required: true
  prop invite, :event, required: true
  prop remove, :event, required: true
  prop suggest, :event
  prop collaborators, :any, default: []
  prop matches, :any, default: []
  prop to_invite, :any, default: :collaborator
  prop search_field, :any, default: :email
  prop main_fields, :keyword, default: [primary: :name, secondary: :email]
  prop placeholder, :string, default: "collaborator@example.edu"
  prop button_text, :string, default: "Send invite"
  prop allow_removal, :boolean, default: true

  def render(assigns) do
    ~F"""
      <Form for={@to_invite} submit={@invite} change={@suggest} class="d-flex mb-5">
        <Field name={@search_field} class="w-100">
          <TextInput class="form-control" opts={placeholder: @placeholder, autocomplete: "off", list: @list_id}/>
          <datalist id={@list_id}>
            {#for match <- @matches}
              <option value={Map.get(match, @search_field)}>{Map.get(match, @main_fields[:primary])}</option>
            {/for}
          </datalist>
          <ErrorTag/>
        </Field>
        <button class="form-button btn btn-outline-primary" type="submit">{@button_text}</button>
      </Form>
      {#for collaborator <- @collaborators}
        <div class="d-flex justify-content-between align-items-center mb-3">
          <div class="d-flex flex-column">
            <div>{Map.get(collaborator, @main_fields[:primary])}</div>
            <div class="text-muted">{Map.get(collaborator, @main_fields[:secondary])}</div>
          </div>
          {#if @allow_removal}
            <div class="user-actions">
              <button class="btn btn-link text-danger" :on-click={@remove} phx-value-collaborator-id={collaborator.id}>Remove</button>
            </div>
          {/if}
        </div>
      {/for}
    """
  end
end
