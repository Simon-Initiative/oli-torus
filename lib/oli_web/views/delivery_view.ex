defmodule OliWeb.DeliveryView do
  use OliWeb, :view

  alias Oli.Lti;

  def user_role(current_user), do: Lti.parse_lti_role(current_user.roles)

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

  def account_linked?(current_user) do
    IO.inspect(current_user)
    current_user.author_id != nil
  end

end
