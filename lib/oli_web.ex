defmodule OliWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use OliWeb, :controller
      use OliWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: OliWeb

      import Plug.Conn
      import OliWeb.Gettext
      import OliWeb.Pow.PowHelpers
      import Phoenix.LiveView.Controller
      alias OliWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/oli_web/templates",
        namespace: OliWeb

      use Appsignal.Phoenix.View

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {OliWeb.LayoutView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  def surface_view do
    quote do
      use Surface.LiveView,
        layout: {OliWeb.LayoutView, "live.html"}

      import Oli.Utils.Surface

      unquote(view_helpers())
    end
  end

  def surface_component do
    quote do
      use Surface.LiveComponent

      import Oli.Utils.Surface

      unquote(view_helpers())
    end
  end

  def mailer_view do
    quote do
      use Phoenix.View,
        root: "lib/oli_web/templates",
        namespace: OliWeb

      use Phoenix.HTML
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import OliWeb.Gettext
    end
  end

  defp view_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers
      import OliWeb.LiveHelpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import OliWeb.ErrorHelpers
      import OliWeb.Gettext

      import OliWeb.ViewHelpers
      import OliWeb.Common.FormatDateTime

      import Oli.Accounts,
        only: [
          author_signed_in?: 1,
          user_signed_in?: 1,
          user_is_guest?: 1,
          user_is_independent_learner?: 1
        ]

      import Oli.Utils
      import Oli.Branding
      import Oli.Utils.SchemaResolver, only: [schemas: 0]

      alias OliWeb.Router.Helpers, as: Routes

      import ReactPhoenix.ClientSide
    end
  end

  # implement Phoenix.HTML.Safe for Map type. Used by some json views
  defimpl Phoenix.HTML.Safe, for: Map do
    def to_iodata(data), do: data |> Jason.encode!() |> Plug.HTML.html_escape()
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
