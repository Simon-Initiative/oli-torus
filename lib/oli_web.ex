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

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def controller do
    quote do
      use Phoenix.Controller, layouts: [html: {OliWeb.LayoutView, :app}], namespace: OliWeb
      use Gettext, backend: OliWeb.Gettext

      import Plug.Conn
      import Phoenix.LiveView.Controller

      alias OliWeb.Router.Helpers, as: Routes

      unquote(verified_routes())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  # deprecated view function
  def view do
    quote do
      use Phoenix.View,
        root: "lib/oli_web/templates",
        namespace: OliWeb

      use Appsignal.Phoenix.View

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [view_module: 1, view_template: 1]

      import Phoenix.Component

      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {OliWeb.LayoutView, :live}

      # Define on_mount for all live views
      #
      # NOTE: for a live_session that specifies on_mount, this will be called
      # after the specified on_mounts, and therefore should be included
      # in the live_session on_mount if needed before other on_mount plugs
      on_mount OliWeb.LiveSessionPlugs.SetToken

      unquote(socket_helpers())
      unquote(html_helpers())
    end
  end

  defp socket_helpers() do
    quote do
      import OliWeb.Live.TaggedTupleHelper
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
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
      import Phoenix.Component
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      use Gettext, backend: OliWeb.Gettext
    end
  end

  defp html_helpers do
    quote do
      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      use Gettext, backend: OliWeb.Gettext

      # Import LiveView helpers (live_render, live_component, live_patch, etc)
      import Phoenix.LiveView.Helpers

      # Import basic rendering functionality (render, render_layout, etc)
      import Phoenix.View

      import OliWeb.ErrorHelpers

      import OliWeb.ViewHelpers
      import OliWeb.Common.FormatDateTime

      import OliWeb.Components.Delivery.Utils,
        only: [
          user_is_guest?: 1
        ]

      import Oli.Utils
      import Oli.Branding

      alias OliWeb.Router.Helpers, as: Routes

      alias OliWeb.Components

      import OliWeb.Components.Common

      import ReactPhoenix.ClientSide

      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: OliWeb.Endpoint,
        router: OliWeb.Router,
        statics: OliWeb.static_paths()
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
