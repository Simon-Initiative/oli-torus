defmodule Oli.Conversation.ConversationMessageTest do
  use Oli.DataCase, async: true

  alias Oli.Conversation.ConversationMessage

  describe "changeset/2" do
    test "casts llm metadata fields" do
      attrs = %{
        role: :assistant,
        content: "hello",
        user_id: 1,
        section_id: 2,
        llm_provider_type: :open_ai,
        llm_provider_url: "https://api.example.com/v1",
        llm_model: "gpt-4.1"
      }

      changeset = ConversationMessage.changeset(%ConversationMessage{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :llm_provider_type) == :open_ai

      assert Ecto.Changeset.get_change(changeset, :llm_provider_url) ==
               "https://api.example.com/v1"

      assert Ecto.Changeset.get_change(changeset, :llm_model) == "gpt-4.1"
    end

    test "allows llm metadata fields to be nil" do
      attrs = %{
        role: :user,
        content: "hello",
        user_id: 1,
        section_id: 2
      }

      changeset = ConversationMessage.changeset(%ConversationMessage{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :llm_provider_type) == nil
      assert Ecto.Changeset.get_field(changeset, :llm_provider_url) == nil
      assert Ecto.Changeset.get_field(changeset, :llm_model) == nil
    end
  end
end
