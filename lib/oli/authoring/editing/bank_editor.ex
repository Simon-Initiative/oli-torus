defmodule Oli.Authoring.Editing.BankEditor do
  @moduledoc """
  This module provides content editing facilities for banked activities.

  """

  @doc """
  Creates the context necessary to power a client side activity bank editor.
  """
  def create_context(project_slug, author) do
    Oli.Authoring.Editing.ActivityBank.context(project_slug, author)
  end
end
