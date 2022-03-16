export type ClassName = string | null | undefined | false;

export const classNames = (...names: ClassName[]) => {
  return names.filter((n) => n).join(' ');
};
