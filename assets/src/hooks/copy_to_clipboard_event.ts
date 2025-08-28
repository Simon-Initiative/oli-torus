export const CopyToClipboardEvent = {
  mounted() {
    this.handleEvent('copy_to_clipboard', ({ text }) => {
      navigator.clipboard.writeText(text).then(() => {
        console.log('Text copied to clipboard:', text);
      }).catch(err => {
        console.error('Failed to copy text to clipboard:', err);
      });
    });
  },
};
