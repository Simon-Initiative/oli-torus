import * as Immutable from 'immutable';
import { Objective } from 'data/content/objective';

/**
 * Takes an array of objectives and arranges them in a list so that child
 * objectives immediately follow their parent.
 *
 * @param objectives an array of objectives to arrange
 * @returns the arranged objectives as an immutable list
 */
export function arrangeObjectives(objectives: Objective[]): Immutable.List<Objective> {
  // Bucket objectives by parent

  const byId = objectives.reduce((m: any, o: any) => {
    m[o.id] = o;
    return m;
  }, {});

  const bucketed = objectives.reduce((m: any, o: any) => {
    if (o.parentId !== null && byId[o.parentId] !== undefined) {
      if (m[o.parentId] === undefined) {
        m[o.parentId] = [o.id];
      } else {
        m[o.parentId] = [...m[o.parentId], o.id];
      }
    } else if (m[o.id] === undefined) {
      m[o.id] = [];
    }
    return m;
  }, {});

  const inOrder = Object.keys(bucketed).reduce((all: any, key: any) => {
    const parentWithChildren = [byId[key], ...bucketed[key].map((k: any) => byId[k])];
    return [...all, ...parentWithChildren];
  }, []);

  return Immutable.List<Objective>(inOrder);
}
