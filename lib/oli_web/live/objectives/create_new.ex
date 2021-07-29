defmodule OliWeb.Objectives.CreateNew do
  @moduledoc """
  Objective create component.
  """

  use Phoenix.LiveComponent
  use Phoenix.HTML
  import OliWeb.ErrorHelpers

  def render(assigns) do
    ~L"""
    <style>
    .form-grow {
    flex-grow: 1;
    }
    </style>

    <div class="mb-2 mt-5 row">
        <div class="col-12">
          <p>At the end of the course, students should be able to...</p>
        </div>
      </div>
      <div class="mb-2 row">
        <div class="col-12">

          <div class="d-flex form-grow">
          <%= f = form_for @changeset, "#", [phx_submit: "new", id: "form-create-objective", class: "form-inline form-grow"] %>
            <%= text_input f,
              :title,
              class: "form-control form-control-sm mb-2 mr-sm-2 mb-sm-0 title container-fluid form-grow" <> error_class(f, :title, "is-invalid"),
              id: "form-create-objective",
              placeholder: "e.g. Recognize the structures of amino acids, carbohydrates, lipids, and nucleic acids",
              required: true %>

            <%= error_tag f, :title %>
            <%= submit "Create", class: "btn btn-primary ob-form-button btn-sm" %>
            </form>
          </div>

        </div>
      </div>

    """
  end
end
