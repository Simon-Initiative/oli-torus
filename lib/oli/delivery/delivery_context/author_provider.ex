defmodule Oli.Delivery.DeliveryContext.AuthorProvider do
  @moduledoc """
  Implements the UserResolver behavior for resolving an author for previewing the delivery views.
  """

  alias Oli.Delivery.DeliveryContext
  alias Oli.Delivery.DeliveryContext.DeliveryContextProvider

  @behaviour DeliveryContextProvider

  @impl DeliveryContextProvider
  def name(%DeliveryContext{author: author}) do
    author.name
  end

  @impl DeliveryContextProvider
  def is_guest(%DeliveryContext{}) do
    false
  end

  @impl DeliveryContextProvider
  def user_effective_role(%DeliveryContext{}) do
    :student
  end

  def maybe_real_user_id(%DeliveryContext{}) do
    nil
  end
end
