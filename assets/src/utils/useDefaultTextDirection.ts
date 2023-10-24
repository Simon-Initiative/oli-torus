import { TextDirection } from 'data/content/model/elements/types';
import { useStateFromLocalStorage } from './useStateFromLocalStorage';

export const useDefaultTextDirection = () =>
  useStateFromLocalStorage<string>('ltr', 'lastTextDirection');

export const getDefaultTextDirection = (): TextDirection => {
  switch (JSON.parse(localStorage.getItem('lastTextDirection') || '"ltr"')) {
    case 'rtl':
      return 'rtl';
    default:
      return 'ltr';
  }
};
