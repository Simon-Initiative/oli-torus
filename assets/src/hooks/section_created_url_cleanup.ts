export const SectionCreatedUrlCleanup = {
  mounted() {
    const url = new URL(window.location.href);

    if (url.searchParams.get('section_created') !== 'true') {
      return;
    }

    url.searchParams.delete('section_created');

    window.history.replaceState(
      window.history.state,
      '',
      `${url.pathname}${url.search}${url.hash}`,
    );
  },
};
