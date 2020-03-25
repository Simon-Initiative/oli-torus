defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Lti;

  def user_role_text(current_user) do
    role = Lti.parse_lti_role(current_user.roles)
    case role do
      :student -> "Student"
      :instructor -> "Instructor"
      :administrator -> "Administrator"
    end
  end

  def user_role_color(current_user) do
    role = Lti.parse_lti_role(current_user.roles)
    case role do
      :student -> "#3498db"
      :instructor -> "#2ecc71"
      :administrator -> "#f39c12"
    end
  end
end
