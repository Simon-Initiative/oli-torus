const isValidEmail = (email: string): boolean =>
  email.match(/^[\w]+@([\w-]+\.)+[\w-]{2,4}$/) !== null;

const parseEmails = (content: string): string[] =>
  content.match(/[\w]+@([\w-]+\.)+[\w-]{2,4}/g) || [];

export const EmailList = {
  refresh() {
    const element = this.el as HTMLDivElement;
    const phxEvent = element.getAttribute('phx-event');
    const input = element.querySelector('input') as HTMLInputElement;
    input.focus();
    element.addEventListener('click', (event: any) => {
      if (event.target.matches(`#${element.id}`) && !input.getAttribute('focus')) {
        input.focus();
      }
    });
    input.addEventListener('input', () => {
      input.style.width = 'auto';
      input.style.width = `${input.scrollWidth}px`;
    });
    input.addEventListener('keypress', (event: KeyboardEvent) => {
      if (event.code === 'Enter' || event.code === 'Comma') {
        input.blur();
      }
    });
    input.addEventListener('blur', () => {
      const value = input.value.trim();
      isValidEmail(value)
        ? this.pushEvent(phxEvent, {
            value,
          })
        : (input.value = '');
    });
    input.addEventListener('paste', (event: ClipboardEvent) => {
      event.preventDefault();

      const clipboardData = event.clipboardData || (window as any).clipboardData;
      const pastedText = clipboardData?.getData('text/plain');

      const emails = parseEmails(pastedText);

      if (emails.length) {
        this.pushEvent(phxEvent, {
          value: emails,
        });
      }
    });
  },
  mounted() {
    this.refresh();
  },
  updated() {
    this.refresh();
  },
};
