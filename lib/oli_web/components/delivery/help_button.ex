defmodule OliWeb.Components.Delivery.HelpButton do
  use Phoenix.Component

  alias OliWeb.Router.Helpers, as: Routes

  def help_button(assigns) do
    ~H"""
    <!-- Button trigger modal -->
    <button
      type="button"
      class="btn btn-xs btn-light inline-flex items-center help-btn m-1"
      data-bs-toggle="modal"
      data-bs-target="#help-modal"
    >
      <img
        src={Routes.static_path(OliWeb.Endpoint, "/images/icons/life-ring-regular.svg")}
        class="help-icon mr-1"
      />
      <span>Help</span>
    </button>
    """
  end
end
