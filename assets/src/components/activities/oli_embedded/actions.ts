import { Maybe } from 'tsmonad';
import { Identifiable } from 'data/content/model';

export class OliEmbeddedActions {
  private static getById<T extends Identifiable>(slice: T[], id: string): Maybe<T> {
    return Maybe.maybe(slice.find((c) => c.id === id));
  }
}
