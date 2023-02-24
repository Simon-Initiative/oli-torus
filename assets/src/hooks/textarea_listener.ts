export const TextareaListener = {
  mounted(): void {
    (window as any).resizeTextArea = function resizeTextArea(textarea: HTMLTextAreaElement) {
      textarea.style.height = `${textarea.dataset.initialHeight}px`;
      textarea.style.height = `${textarea.scrollHeight}px`;
    };

    document.querySelectorAll('[data-grow="true"]').forEach((textarea: HTMLTextAreaElement) => {
      textarea.style.height = `${textarea.dataset.initialHeight}px`;
    });
  },
  updated(): void {
    document.querySelectorAll('[data-grow="true"]').forEach((window as any).resizeTextArea);
  },
};
