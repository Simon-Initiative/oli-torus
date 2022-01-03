defmodule Oli.Analytics.Datashop.Messages.Context do
  @moduledoc """
  <context_message context_message_id="t.stark+0@avengers.com-one-part1" name="START_PROBLEM">
    <meta>
      <user_id>t.stark+0@avengers.com</user_id>
      <session_id>6c6d381e-1598-4924-9b60-30dce843e417</session_id>
      <time>2020-06-30 00:18</time>
      <time_zone>GMT</time_zone>
    </meta>
    <dataset>
      <name>example_course-XVeLxRjNVUdSnzsMuFeZNn</name>
      <name>Activity one</name>
      <problem_name>Activity one, part 1</problem_name>
    </dataset>
  </context_message>
  """
  import XmlBuilder
  alias Oli.Analytics.Datashop.Elements.{Meta, Dataset}

  def setup(name, context) do
    element(
      :context_message,
      %{
        context_message_id: context.context_message_id,
        name: name
      },
      [
        Meta.setup(context),
        Dataset.setup(context)
      ]
    )
  end
end
