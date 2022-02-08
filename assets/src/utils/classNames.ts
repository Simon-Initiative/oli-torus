export const classNames = (names: string | (string | null | undefined | false)[]) => {
  if (typeof names === 'string') {
    return names.trim();
  }

  return names.filter((n) => n).join(' ');
};
