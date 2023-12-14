const isValidEmail = (email: string): boolean =>
  email.match(/^[a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}$/) !== null;

const parseEmails = (content: string): string[] =>
  content.match(/[a-zA-Z0-9._+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}/g) || [];

const isEmailAlreadyIncluded = (email: string): boolean => {
  const enrollments_email_list_div = document.getElementById(
    'enrollments_email_list',
  ) as HTMLDivElement;
  const divCollection = enrollments_email_list_div!.getElementsByTagName('div') as HTMLCollection;
  const arr = [].slice.call(divCollection);
  const emailList = arr.map((element: any) => element.querySelector('p').innerHTML);
  return emailList.includes(email);
};

export const EmailList = {
  maybePushEventToTarget(phxTarget: string | null, phxEvent: string | null, value: string) {
    console.log(phxTarget);
    if (phxTarget) {
      this.pushEventTo(`#${phxTarget}`, phxEvent, { value: value });
    } else {
      this.pushEvent(phxEvent, { value });
    }
  },

  refresh() {
    const element = this.el as HTMLDivElement;
    const phxEvent = element.getAttribute('phx-event');
    const phxTarget = element.getAttribute('phx-target-id');
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

      if (isEmailAlreadyIncluded(value)) {
        input.value = '';
      }

      if (isValidEmail(value)) {
        this.maybePushEventToTarget(phxTarget, phxEvent, value);
      } else {
        input.value = '';
      }
    });
    input.addEventListener('paste', (event: ClipboardEvent) => {
      event.preventDefault();

      const clipboardData = event.clipboardData || (window as any).clipboardData;
      const pastedText = clipboardData?.getData('text/plain');

      const emails = parseEmails(pastedText);

      if (emails.length) {
        this.maybePushEventToTarget(phxTarget, phxEvent, emails);
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
