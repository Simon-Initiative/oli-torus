import { Identifiable } from 'data/content/model';
import { Maybe } from 'tsmonad';

// Helper. Assumes a correct ID is given
export function getByIdUnsafe<T extends Identifiable>(slice: T[], id: string): T {
  return Maybe.maybe(slice.find((c) => c.id === id)).valueOrThrow(
    new Error('Could not find item with id ' + id + ' in list ' + JSON.stringify(slice)),
  );
}
