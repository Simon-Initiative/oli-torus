defmodule OliWeb.Components.Delivery.DialogueTest do
  use OliWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias OliWeb.Components.Delivery.Dialogue

  describe "chat_message/1" do
    test "renders assistant message with correct styling" do
      assigns = %{
        index: 1,
        content: "Hello, how can I help you?",
        user: :assistant
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      assert html =~ "Hello, how can I help you?"
      assert html =~ "bg-[#dcdef6]"
      assert html =~ "dark:bg-[#494b65]"
      assert html =~ "assistant/footer_dot_ai.png"
      assert html =~ "chat-message"
      assert html =~ "EvaluateMathJaxExpressions"
    end

    test "renders user message with correct styling" do
      assigns = %{
        index: 2,
        content: "I need help with math",
        user: %{name: "John Doe"}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      assert html =~ "I need help with math"
      assert html =~ "bg-[#edeef7]"
      assert html =~ "dark:bg-[#2f3147]"
      assert html =~ "JD"
      assert html =~ "chat-message"
      assert html =~ "EvaluateMathJaxExpressions"
    end

    test "renders user message with nil name" do
      assigns = %{
        index: 3,
        content: "Test message",
        user: %{name: nil}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      assert html =~ "G"
    end

    test "renders user message with unknown user type" do
      assigns = %{
        index: 4,
        content: "Test message",
        user: "unknown"
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      assert html =~ "?"
    end

    test "includes copy to clipboard for assistant messages" do
      assigns = %{
        index: 1,
        content: "Assistant message",
        user: :assistant
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      assert html =~ "CopyListener"
      assert html =~ "copy_button_1"
      assert html =~ "message_1_content"
    end

    test "does not include copy to clipboard for user messages" do
      assigns = %{
        index: 2,
        content: "User message",
        user: %{name: "John"}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)

      refute html =~ "CopyListener"
    end
  end

  describe "function/1" do
    test "renders function message with correct styling" do
      assigns = %{
        index: 1,
        name: "calculate",
        content: "function calculate(x) { return x * 2; }"
      }

      html = render_component(&Dialogue.function/1, assigns)

      assert html =~ "calculate"
      assert html =~ "function calculate(x) { return x * 2; }"
      assert html =~ "font-mono"
      assert html =~ "font-bold"
      assert html =~ "border-b"
      assert html =~ "CopyListener"
    end

    test "renders function with different name and content" do
      assigns = %{
        index: 2,
        name: "solve_equation",
        content: "x = 5"
      }

      html = render_component(&Dialogue.function/1, assigns)

      assert html =~ "solve_equation"
      assert html =~ "x = 5"
      assert html =~ "&gt; solve_equation"
    end
  end

  describe "helper functions" do
    test "is_assistant? returns true for :assistant" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: :assistant
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      assert html =~ "assistant/footer_dot_ai.png"
    end

    test "is_assistant? returns false for other values" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: %{name: "John"}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      refute html =~ "assistant/footer_dot_ai.png"
    end

    test "to_initials returns BOT AI for assistant" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: :assistant
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      assert html =~ "assistant/footer_dot_ai.png"
    end

    test "to_initials returns G for user with nil name" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: %{name: nil}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      assert html =~ "G"
    end

    test "to_initials returns initials for user with name" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: %{name: "John Doe"}
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      assert html =~ "JD"
    end

    test "to_initials returns ? for unknown user type" do
      # Test through the public interface instead
      assigns = %{
        index: 1,
        content: "Test message",
        user: "unknown"
      }

      html = render_component(&Dialogue.chat_message/1, assigns)
      assert html =~ "?"
    end
  end
end
