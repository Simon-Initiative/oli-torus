const parseEmails = (content: string): string[] => {
  // Split content on common delimiters
  const potentialEmails = content.split(/[\s,;]+/);

  // Filter and return only valid emails
  return potentialEmails.map((email) => email.trim()).filter((email) => email.length > 0);
};

const isEmailAlreadyIncluded = (email: string): boolean => {
  const enrollments_email_list_div = document.getElementById('email-list-container');
  if (!enrollments_email_list_div) return false;

  const divCollection = enrollments_email_list_div.getElementsByTagName('div');
  if (!divCollection.length) return false;

  const emailList = Array.from(divCollection)
    .map((element) => element.querySelector('p')?.innerHTML)
    .filter(Boolean);

  return emailList.includes(email);
};

const pushEventToTarget = (
  element: any,
  phxTarget: string | null,
  phxEvent: string | null,
  value: string | string[],
) => {
  element.pushEventTo(`#${phxTarget}`, phxEvent, { value: value });
};

export const EmailList = {
  refresh() {
    const element = this.el as HTMLDivElement;
    const phxEvent = element.getAttribute('phx-event');
    const phxTarget = element.getAttribute('phx-target-id');
    const input = element.querySelector('input') as HTMLInputElement;

    if (!input) return;

    input.focus();
    element.addEventListener('click', (event: any) => {
      const target = event.target as HTMLElement;
      if (target.matches(`#${element.id}`) && !input.getAttribute('focus')) {
        input.focus();
      }
    });

    input.addEventListener('input', () => {
      input.style.width = 'auto';
      input.style.width = `${input.scrollWidth}px`;
    });

    input.addEventListener('keypress', (event: KeyboardEvent) => {
      if (event.code === 'Enter' || event.code === 'Comma') {
        event.preventDefault();
        input.blur();
      }
    });

    input.addEventListener('blur', () => {
      const value = input.value.trim();

      if (value && !isEmailAlreadyIncluded(value)) {
        pushEventToTarget(this, phxTarget, phxEvent, value);
        input.value = '';
      } else {
        input.value = '';
      }
    });

    input.addEventListener('paste', (event: ClipboardEvent) => {
      event.preventDefault();

      const clipboardData = event.clipboardData || (window as any).clipboardData;
      const pastedText = clipboardData?.getData('text/plain');

      const emails = parseEmails(pastedText);
      const validEmails = emails.filter((email) => !isEmailAlreadyIncluded(email));

      if (validEmails.length) {
        pushEventToTarget(this, phxTarget, phxEvent, validEmails);
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
