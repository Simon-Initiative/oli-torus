defmodule OliWeb.Experiments.SyncButton  do
  use Phoenix.Component

  attr :sync_result, :atom, required: true

  def sync_button(%{sync_result: :default} = assigns) do
    ~H"""
    <button class="btn btn-sm btn-primary" phx-click="sync">Synchronize</button>
    """
  end

  def sync_button(%{sync_result: :success} = assigns) do
    ~H"""
    <button class="btn btn-sm btn-success">Synchronized!</button>
    """
  end

  def sync_button(%{sync_result: :failed} = assigns) do
    ~H"""
    <button class="btn btn-sm btn-error">Something went wrong</button>
    """
  end
end
