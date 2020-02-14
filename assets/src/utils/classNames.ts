export const classNames = (names: string | (string | null | undefined)[]) => {
  if (typeof names === 'string') {
    return names.trim();
  }
  
  return names.filter(n => n).join(' ');
};
  
