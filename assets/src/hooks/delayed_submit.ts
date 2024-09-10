export const DelayedSubmit = {
  mounted() {
    this.el.addEventListener("click", (event: any) => {
      event.preventDefault(); // Prevent immediate click action

      const inputs = document.querySelectorAll('input[type="text"], input[type="number"], textarea, select');

      // Loop through each element and disable it.  This prevents students from making any
      // edits in activities while the submission is processing.
      inputs.forEach((input: any) => {
        input.disabled = true;
      });

      // Disable the button to prevent additional clicks
      this.el.disabled = true;

      // Change the button label and show the spinner
      this.el.querySelector(".button-text").textContent = "Submitting Answers...";
      this.el.querySelector(".spinner").classList.remove("hidden");

      // Delay the phx-click event by two full seconds
      setTimeout(() => {
        // Trigger the Phoenix event after the delay
        this.pushEvent("finalize_attempt");

        // Optionally, remove the spinner and reset button state if needed
      }, 2000);
    });
  },
};
