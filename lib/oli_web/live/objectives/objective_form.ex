defmodule OliWeb.Objectives.ObjectiveForm do

  @moduledoc """
  Curriculum item entry component.
  """
  import OliWeb.ErrorHelpers
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
      <div class="d-flex flex-grow-1">
        <%= f = form_for @changeset, "#", [phx_submit: @method, id: "form-" <> @form_id, class: "form-inline form-grow"] %>
        <%= text_input f,
          :title,
          value: @title_value,
          class: "form-control form-control-sm mb-2 mr-sm-2 mb-sm-0 title container-fluid form-grow" <> error_class(f, :title, "is-invalid"),
          placeholder: @place_holder,
          id: "input-title-" <> @form_id,
          phx_hook: "InputAutoSelect",
          required: true %>
        <%= hidden_input f,
          :parent_slug,
          value: @parent_slug_value %>
        <%= hidden_input f,
          :slug,
          value: @slug_value %>
        <%= error_tag f, :title %>
        <%= submit @button_text, class: "btn btn-primary ob-form-button btn-sm" %>
        </form>

        <button
          phx-click="cancel"
          class = "mx-1 btn btn-outline-primary btn-sm">
          Cancel
        </button>
      </div>
    """
  end
end
