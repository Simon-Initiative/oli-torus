// Listens for user input in the text input identified by 'inputSelector', and keeps the submit
// button identified by 'submitSelector' disabled until the user's base 64 encode
// input matches the text of 'encodedTitle'.  Comparison of base 64 encodings instead of the raw
// strings is a robust way to circumvent a confusting array of server/client encoding/decoding challenges.
//
// This is used during confirmation of package deletion.
export function enableSubmitWhenTitleMatches(
  inputSelector: string,
  submitSelector: string,
  encodedTitle: string,
): void {
  const deleteTitleInput = document.querySelector(inputSelector);
  if (deleteTitleInput) {
    deleteTitleInput.addEventListener('input', function (e: any) {
      const value = e.target.value;
      const deleteSubmitButton: HTMLInputElement | null = document.querySelector(submitSelector);
      if (deleteSubmitButton !== null) {
        // Base 64 encode the user's input and compare it to the encoded title
        if (btoa(value) === encodedTitle) {
          deleteSubmitButton.disabled = false;
        } else {
          deleteSubmitButton.disabled = true;
        }
      }
    });
  }
}
