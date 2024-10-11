defmodule Oli.Delivery.DeliveryContext.DeliveryContextProvider do
  @moduledoc """
  This module defines the behavior for any provider that can be used to resolve data for delivery views.

  The methods in this module provide an abstraction over directly querying the database or other hard coded
  operations in the delivery views in order to facilitate the different delivery and preview modes.

  A `DeliveryContextProvider` implements the behavior for resolving relevant details from a given context.
  These contexts primarily consist of student/instructor delivery and authoring/admin preview, but
  could also later be extended to include a lightweight guest mode, etc.

  The intended use of this module is to call the functions in this module from the delivery views,
  supplying the current delivery context as an argument. The provider will then resolve the
  necessary data based on the context's resolver and return it to the caller. This allows the
  delivery views to remain agnostic of the actual data source and to be easily switched between
  different modes. Some data may be loaded up front into the context to avoid repeated queries,
  while other data may be resolved on demand.
  """

  alias Oli.Delivery.DeliveryContext

  @doc """
  Returns the current user's full name.
  """
  @callback name(%DeliveryContext{}) :: String.t()

  @doc """
  Returns true if the current user is a guest user, false otherwise.
  """
  @callback is_guest(%DeliveryContext{}) :: boolean()

  @doc """
  Returns the effective role of the current user in the given context. The effective role can
  either be `:student` or `:instructor`.

  This is intended to be a temporary solution until we have a more robust role system in place.
  """
  @callback user_effective_role(%DeliveryContext{}) :: Atom.t()

  @doc """
  Returns the current user id if the user is actually backed by a real database user record.
  Otherwise, returns nil.

  Some features in the delivery views may require a real user id to function, such as the ability to track
  student progress, record student responses or create user-associated records such as annotations. For
  cases where the user is not backed by a real user record, features can pattern match on the
  `nil` return value and provide a fallback behavior or disable the feature altogether.
  """
  @callback maybe_real_user_id(%DeliveryContext{}) :: integer() | nil

  @behaviour __MODULE__

  def name(context) do
    context.provider.name(context)
  end

  def is_guest(context) do
    context.provider.is_guest(context)
  end

  def user_effective_role(context) do
    context.provider.user_effective_role(context)
  end

  def maybe_real_user_id(context) do
    context.provider.maybe_real_user_id(context)
  end
end
