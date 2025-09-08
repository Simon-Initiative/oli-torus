export const TagsComponent = {
  mounted() {
    this.handleEvent(
      'focus_input',
      ({ input_id, clear }: { input_id: string; clear?: boolean }) => {
        // Use setTimeout to ensure the DOM has been updated
        setTimeout(() => {
          const input = document.getElementById(input_id) as HTMLInputElement;
          if (input) {
            if (clear === true) {
              input.value = '';
            }
            input.focus();
          }
        }, 50);
      },
    );
  },
};
