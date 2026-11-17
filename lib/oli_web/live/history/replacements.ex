defmodule OliWeb.RevisionHistory.Replacements do
  @moduledoc """
  Revision history writes shared by `OliWeb.RevisionHistory` and
  `OliWeb.Workspaces.CourseAuthor.HistoryLive`. Each runs an `Oli.Authoring.Audited` command as
  the current author and, on success, selects the new revision; on failure it flashes an error
  and leaves the selection unchanged.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited

  @doc "Restores the `selected` revision as the resource's new head."
  @spec restore(Phoenix.LiveView.Socket.t(), Oli.Resources.Revision.t()) ::
          {:ok | :error, Phoenix.LiveView.Socket.t()}
  def restore(socket, selected) do
    socket
    |> audit_context()
    |> Audited.restore_revision(socket.assigns.project, socket.assigns.resource_id, selected.id)
    |> select_result(socket)
  end

  @doc "Replaces the resource's content with `content` (edited or uploaded JSON)."
  @spec replace_content(Phoenix.LiveView.Socket.t(), map()) ::
          {:ok | :error, Phoenix.LiveView.Socket.t()}
  def replace_content(socket, content) do
    socket
    |> audit_context()
    |> Audited.replace_revision_content(
      socket.assigns.project,
      socket.assigns.resource_id,
      content
    )
    |> select_result(socket)
  end

  @doc "The audit context of the current author, for the history views' commands."
  @spec audit_context(Phoenix.LiveView.Socket.t()) :: Context.t()
  def audit_context(socket), do: Context.for_actor(socket.assigns.current_author, source: :ui)

  defp select_result({:ok, revision}, socket), do: {:ok, assign(socket, selected: revision)}

  defp select_result({:error, _reason}, socket),
    do:
      {:error,
       put_flash(socket, :error, "The revision could not be saved. Reload and try again.")}
end
