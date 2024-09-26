// This hook is used to disable all the input elements contained in the element where the hook is attached,
// when the element has a data attribute`data-submitted="true"`.
// Since the input elements may not be available immediately after the hook is mounted,
// the hook polls for the input elements every 500ms for a maximum of 5 times.
// This hook can also be triggered from the server side by sending a "disable_question_inputs" event

// Usage:
// <div data-submitted="true" phx-hook="DisableSubmitted" >...</div>
// will disable all the input elements contained in the div
//
// <div data-submitted="false" phx-hook="DisableSubmitted" >...</div>
// will not disable any input elements contained in the div

function disableInputsInElement(element: HTMLElement | null) {
  if (!element) {
    return;
  }

  const inputs = element.querySelectorAll('input, select, textarea, button');

  if (inputs.length > 0) {
    inputs.forEach(
      (input: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLButtonElement) => {
        input.disabled = true;
      },
    );
  }
}

export const DisableSubmitted = {
  mounted() {
    this.disableInputsIfSubmitted();
    this.pollingAttempts = 0;
    this.maxPollingAttempts = 5;
    this.startPolling();

    // Listen for the "disable_inputs" event that may be triggered when te user submits a question
    this.handleEvent('disable_question_inputs', (payload: any) => {
      if (payload.question_id === this.el.id) {
        const question = document.getElementById(this.el.id);
        disableInputsInElement(question);
      }
    });
  },
  startPolling() {
    this.pollingInterval = setInterval(() => {
      this.pollingAttempts += 1;
      this.disableInputsIfSubmitted();

      if (this.pollingAttempts >= this.maxPollingAttempts) {
        // Max polling attempts reached, stopping polling
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }
    }, 500);
  },
  updated() {
    this.disableInputsIfSubmitted();
  },
  destroyed() {
    // Stop polling when the hook is destroyed
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  },
  disableInputsIfSubmitted() {
    const submitted = this.el.dataset.submitted === 'true';

    if (submitted) {
      const inputs = this.el.querySelectorAll('input, select, textarea, button');
      console.log('Number of inputs found:', inputs.length);

      if (inputs.length > 0) {
        inputs.forEach(
          (
            input: HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLButtonElement,
          ) => {
            input.disabled = true;
          },
        );
        // Stop polling since we have disabled the inputs
        if (this.pollingInterval) {
          clearInterval(this.pollingInterval);
          this.pollingInterval = null;
        }
      }
    }
  },
};
