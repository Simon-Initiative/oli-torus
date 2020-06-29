defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view

  alias Oli.Delivery.Lti

  def is_instructor?(conn) do
    user = conn.assigns.current_user
    role = Lti.parse_lti_role(user.roles)

    role == :administrator or role == :instructor
  end

  def calculate_score_percentage(resource_access) do
    case {resource_access.score, resource_access.out_of} do
      {nil, nil} ->
        # resource was accessed but no attempt was submitted
        ""
      {score, out_of} ->
        if out_of != 0 do
          percent = (score / out_of) * 100
            |> round
            |> Integer.to_string

          percent <> "%"
        else
          "0%"
        end
    end
  end
end
