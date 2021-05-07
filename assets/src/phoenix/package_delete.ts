
// Listens for user input in the text input identified by 'inputSelector', and keeps the submit
// button identified by 'submitSelector' disabled until the user's input matches the text of 'title'.
//
// This is used during confirmation of package deletion.
export function enableSubmitWhenTitleMatches(inputSelector: string, submitSelector: string, title: string) : void {

  const deleteTitleInput = document.querySelector(inputSelector);
  if (deleteTitleInput) {
    deleteTitleInput.addEventListener("input", function (e: any) {
      const value = e.target.value;
      const deleteSubmitButton : HTMLInputElement | null = document.querySelector(submitSelector);
      if (deleteSubmitButton !== null) {
        if (value === title) {
          deleteSubmitButton.disabled = false;
        } else {
          deleteSubmitButton.disabled = true;
        }
      }
    });
  }
}
