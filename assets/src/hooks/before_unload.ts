const listener = (e: any) => {
  e.preventDefault();
  e.returnValue = '';
};

export const BeforeUnloadListener = {
  mounted() {
    window.addEventListener('beforeunload', listener);
  },
  destroyed() {
    window.removeEventListener('beforeunload', listener);
  },
};
