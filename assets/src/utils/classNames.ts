export type ClassName = string | null | undefined | false;

export type WithClassName<V> = V & { className?: string };

export const classNames = (...names: ClassName[]) => {
  return names.filter((n) => n).join(' ');
};
