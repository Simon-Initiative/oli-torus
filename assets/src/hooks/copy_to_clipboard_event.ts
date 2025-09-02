export const CopyToClipboardEvent = {
  mounted() {
    this.handleEvent('copy_to_clipboard', ({ text }: { text: string }) => {
      navigator.clipboard
        .writeText(text)
        .then(() => {
          console.log('Text copied to clipboard:', text);
        })
        .catch((err) => {
          console.error('Failed to copy text to clipboard:', err);
        });
    });

    this.handleEvent('remove-overflow-hidden', () => {
      document.body.classList.remove('overflow-hidden');
    });
  },
};
