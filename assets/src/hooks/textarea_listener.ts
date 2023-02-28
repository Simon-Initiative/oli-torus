type SetFocusEvent = {
  id: string;
};

export const TextareaListener = {
  mounted(): void {
    (window as any).resizeTextArea = function resizeTextArea(textarea: HTMLTextAreaElement) {
      textarea.style.height = `${textarea.dataset.initialHeight}px`;
      textarea.style.height = `${textarea.scrollHeight}px`;
    };

    document.querySelectorAll('[data-grow="true"]').forEach((textarea: HTMLTextAreaElement) => {
      textarea.style.height = `${textarea.dataset.initialHeight}px`;
    });

    this.handleEvent('set_focus', ({ id: textAreaId }: SetFocusEvent) => {
      const textarea = document.getElementById(textAreaId) as HTMLTextAreaElement;
      if (textarea) {
        (window as any).resizeTextArea(textarea);
        textarea.focus();
        const value = textarea.value;
        textarea.value = '';
        textarea.value = value;
      }
    });
  },
};
