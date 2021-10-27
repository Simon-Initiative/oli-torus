defmodule OliWeb.Progress.StudentView do
  use Surface.LiveView
  alias OliWeb.Common.{Breadcrumb}
  alias OliWeb.Common.Properties.{Groups, Group, ReadOnly}
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  alias Surface.Components.{Form}
  alias Surface.Components.Form.{Field, Label, NumberInput, ErrorTag}
  alias OliWeb.Progress.AttemptHistory
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.Core

  data breadcrumbs, :any
  data title, :string, default: "Student Progress"
  data section, :any, default: nil
  data user, :any

  defp set_breadcrumbs(type, section) do
    OliWeb.Sections.OverviewView.set_breadcrumbs(type, section)
    |> breadcrumb(section)
  end

  def breadcrumb(previous, _) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Student Progress"
        })
      ]
  end

  def mount(
        %{"section_slug" => section_slug, "user_id" => user_id},
        session,
        socket
      ) do
    case get_user(user_id) do
      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:ok, user} ->
        case Mount.for(section_slug, session) do
          {:error, e} ->
            Mount.handle_error(socket, {:error, e})

          {type, _, section} ->
            resource_accesses =
              Oli.Delivery.Attempts.Core.get_resource_accesses(
                section_slug,
                user_id
              )

            {:ok,
             assign(socket,
               breadcrumbs: set_breadcrumbs(type, section),
               section: section,
               user: user
             )}
        end
    end
  end

  defp get_user(user_id) do
    case Oli.Accounts.get_user!(user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def render(assigns) do
    ~F"""

    """
  end
end
