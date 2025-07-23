defmodule OliWeb.LtiHTML do
  @moduledoc """
  This module contains the HTML components for LTI-related views.

  Using the modern Phoenix 1.7+ pattern with embedded templates.
  """
  use OliWeb, :html

  embed_templates "lti_html/*"
end
