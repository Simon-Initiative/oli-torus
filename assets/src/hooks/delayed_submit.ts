export const DelayedSubmit = {
  mounted() {
    this.el.addEventListener("click", (event: any) => {
      event.preventDefault(); // Prevent immediate click action

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
