export const SectionCreatedUrlCleanup = {
  mounted() {
    const url = new URL(window.location.href);

    if (url.searchParams.get('section_created') !== 'true') {
      return;
    }

    url.searchParams.delete('section_created');
    const query = url.searchParams.toString();
    const cleanUrl = `${url.pathname}${query ? `?${query}` : ''}${url.hash}`;

    window.history.replaceState(window.history.state, '', cleanUrl);
  },
};
