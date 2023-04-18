import * as Factories from './elements/factories';
import * as Elements from './elements/types';
import * as Other from './other';

// export

export const Content = {
  ...Elements,
  ...Factories,
  ...Other,
};
