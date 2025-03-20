defmodule Oli.Rendering.Elements.Plaintext do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Elements

  alias Oli.Rendering.Context
  alias Oli.Rendering.Content
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Group
  alias Oli.Rendering.Survey
  alias Oli.Rendering.Report
  alias Oli.Rendering.Alternatives
  alias Oli.Rendering.Break
  alias Oli.Rendering.LTIExternalTool
  alias Oli.Rendering.Error

  def content(%Context{} = context, element) do
    Content.render(context, element, Content.Plaintext)
  end

  def activity(%Context{} = context, element) do
    Activity.render(context, element, Activity.Plaintext)
  end

  def group(%Context{} = context, element) do
    Group.render(context, element, Group.Plaintext)
  end

  def survey(%Context{} = context, element) do
    Survey.render(context, element, Survey.Plaintext)
  end

  def report(%Context{} = context, element) do
    Report.render(context, element, Report.Plaintext)
  end

  def alternatives(%Context{} = context, element) do
    Alternatives.render(context, element, Alternatives.Plaintext)
  end

  def break(%Context{} = context, element) do
    Break.render(context, element, Break.Plaintext)
  end

  def lti_external_tool(%Context{} = context, element) do
    LTIExternalTool.render(context, element, LTIExternalTool.Plaintext)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end

  def paginate(_id, {rendered, _br_count}), do: rendered
end
