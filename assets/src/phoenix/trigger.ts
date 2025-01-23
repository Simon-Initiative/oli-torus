

export function getInstanceId(): string | null {

  // Fetch the dom element whose id is "ai_bot" and then
  // return the value of the "data-instance-id" attribute.

  const ai_bot = document.getElementById("ai_bot");

  // If the element does not exist, return null.
  if (!ai_bot) {
    return null;
  }
  else {
    return ai_bot.getAttribute("data-instance-id");
  }
}
