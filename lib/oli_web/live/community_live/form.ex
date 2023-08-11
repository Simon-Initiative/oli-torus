defmodule OliWeb.CommunityLive.Form do
  use OliWeb, :html

  attr(:form, :map, required: true)
  attr(:save, :any, required: true)
  attr(:display_labels, :boolean, default: true)

  def render(assigns) do
    ~H"""
    <.form for={@form} phx-submit={@save}>
      <div class="form-group">
        <.input
          class="form-control"
          field={@form[:name]}
          placeholder="Name"
          maxlength={255}
          label={if @display_labels, do: "Community Name"}
        />
      </div>

      <div class="form-group">
        <.input
          type="textarea"
          class="form-control"
          field={@form[:description]}
          placeholder="Description"
          rows="4"
          label={if @display_labels, do: "Community Description"}
        />
      </div>

      <div class="form-group">
        <.input
          class="form-control"
          field={@form[:key_contact]}
          placeholder="Key Contact"
          maxlength={255}
          label={if @display_labels, do: "Community Contact"}
        />
      </div>

      <div class="form-check">
        <.input
          type="checkbox"
          class="form-check-input"
          field={@form[:global_access]}
          label="Access to Global Project or Products"
        />
      </div>

      <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
    </.form>
    """
  end
end
