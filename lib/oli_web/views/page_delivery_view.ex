defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view

  alias Oli.Delivery.Lti

  def is_instructor?(conn) do
    user = conn.assigns.current_user
    role = Lti.parse_lti_role(user.roles)

    role == :administrator or role == :instructor
  end
end
