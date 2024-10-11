defmodule Oli.Delivery.DeliveryContext.UserProvider do
  @moduledoc """
  Implements the DeliveryUser behavior for resolving a student/learner user in delivery views.
  """

  alias Oli.Delivery.DeliveryContext
  alias Oli.Delivery.DeliveryContext.DeliveryContextProvider
  alias Lti_1p3.Tool.ContextRoles

  @behaviour DeliveryContextProvider

  @impl DeliveryContextProvider
  def name(%DeliveryContext{user: user}) do
    user.name
  end

  @impl DeliveryContextProvider
  def is_guest(%DeliveryContext{user: user}) do
    user.guest
  end

  @impl DeliveryContextProvider
  def user_effective_role(%DeliveryContext{context_roles: context_roles}) do
    if ContextRoles.contains_role?(
         context_roles,
         ContextRoles.get_role(:context_instructor)
       ) do
      :instructor
    else
      :student
    end
  end

  def maybe_real_user_id(%DeliveryContext{user: user}) do
    user.id
  end
end
