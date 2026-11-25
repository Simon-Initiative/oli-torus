defmodule Oli.Inventories.Audited do
  @moduledoc """
  Application boundary for audited publisher commands. Each command records
  `publisher_settings_changed` in the same transaction as the change. Commands do not authorize
  the actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Inventories.Publisher

  @doc "Creates a publisher and records its settings."
  @spec create_publisher(Context.t(), map()) :: {:ok, %Publisher{}} | {:error, term()}
  def create_publisher(context, attrs) do
    Command.run(:publisher, fn multi ->
      Command.insert(
        multi,
        :publisher,
        context,
        Publisher.changeset(%Publisher{}, attrs),
        publisher()
      )
    end)
  end

  @doc "Updates the publisher with ID `id` and records the settings that changed."
  @spec update_publisher(Context.t(), pos_integer(), map()) ::
          {:ok, %Publisher{}} | {:error, term()}
  def update_publisher(context, id, attrs) do
    Command.run(:publisher, fn multi ->
      Command.update(
        multi,
        :publisher,
        context,
        {Publisher, id},
        &Publisher.changeset(&1, attrs),
        publisher()
      )
    end)
  end

  @doc """
  Deletes the publisher with ID `id` and records the deletion. The default publisher and
  publishers that still have projects or products return an error changeset, as before.
  """
  @spec delete_publisher(Context.t(), pos_integer()) :: {:ok, %Publisher{}} | {:error, term()}
  def delete_publisher(context, id) do
    spec =
      Map.put(publisher(), :delete, fn
        %Publisher{default: true} = publisher ->
          {:error,
           publisher
           |> Changeset.change()
           |> Changeset.add_error(:default, "cannot delete the default publisher")}

        publisher ->
          publisher
          |> Changeset.change()
          |> Changeset.no_assoc_constraint(:projects)
          |> Changeset.no_assoc_constraint(:products)
      end)

    Command.run(:publisher, &Command.delete(&1, :publisher, context, {Publisher, id}, spec))
  end

  @doc """
  Makes the publisher with ID `id` the default one and removes the flag from the previous
  default, recording one event for each, in the same operation.
  """
  @spec set_default_publisher(Context.t(), pos_integer()) ::
          {:ok, %Publisher{}} | {:error, term()}
  def set_default_publisher(context, id) do
    Command.run(:publisher, fn multi ->
      previous =
        Oli.Repo.all(from(p in Publisher, where: p.default == true and p.id != ^id, select: p.id))

      previous
      |> Enum.reduce(multi, fn previous_id, multi ->
        Command.update(
          multi,
          {:previous, previous_id},
          context,
          {Publisher, previous_id},
          &Publisher.changeset(&1, %{default: false}),
          publisher()
        )
      end)
      |> Command.update(
        :publisher,
        context,
        {Publisher, id},
        &Publisher.changeset(&1, %{default: true}),
        publisher()
      )
    end)
  end

  defp publisher do
    %{
      event_type: :publisher_settings_changed,
      policy: Fields.organization(),
      proposal: fn publisher, operation ->
        %{
          entity: {:publisher, publisher.id, publisher},
          event_key: "publisher:#{publisher.id}:#{operation}"
        }
      end
    }
  end
end
