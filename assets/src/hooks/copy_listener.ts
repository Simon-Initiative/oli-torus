export const CopyListener = {
  mounted() {
    const clipTargetSelector = this.el.dataset['clipboardTarget'];
    const el = this.el;
    const originalHTML = this.el.innerHTML;
    const confirmationMessageId = this.el.dataset['confirmationMessageTarget'] || false;

    function getTargetText(clipTargetSelector: string): string {
      // First, try to get the element using the selector
      const targetElement = document.querySelector(clipTargetSelector);

      if (!targetElement) {
        return ''; // Return an empty string if the element doesn't exist
      }

      let targetText: string;

      // Check if the element is an input or textarea, if so, use its value
      if (
        targetElement instanceof HTMLInputElement ||
        targetElement instanceof HTMLTextAreaElement
      ) {
        targetText = targetElement.value;
      } else {
        // Otherwise, get the innerHTML and remove HTML tags
        targetText = targetElement.innerHTML.replace(/<[^>]*>?/gm, '');
      }

      // Trim initial and final spaces and return
      return targetText.trim();
    }

    this.el.addEventListener('click', (_e: any) => {
      const targetText = getTargetText(clipTargetSelector);

      navigator.clipboard.writeText(targetText).then(function () {
        if (confirmationMessageId) {
          const confirmationMessage = document.querySelector(confirmationMessageId);
          confirmationMessage.classList.remove('hidden');
          confirmationMessage.classList.add('animation-pulse');
          setTimeout(() => {
            confirmationMessage.classList.add('hidden');
            confirmationMessage.classList.remove('animation-pulse');
          }, 750);
        } else {
          el.innerHTML = 'Copied!';
          setTimeout(() => {
            el.innerHTML = originalHTML;
          }, 5000);
        }
      });
    });
  },
};
