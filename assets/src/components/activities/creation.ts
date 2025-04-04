import { ResourceContext } from 'data/content/resource';
import { ActivityModelSchema, CreationContext, Manifest } from './types';

export type creationFn = (context: CreationContext) => Promise<ActivityModelSchema>;

/**
 * Registers a creation function for an activity type.  The creation function
 * is what the system will execute to create new instances of this
 * activity type in an authoring context. The most usual implementation
 * of a creation function is to simply return (i.e. resolve) a default
 * activity model.  But given the async interface here, a creation function
 * can have a more interesting implementation where it makes a network request
 * to a third-party server to retrieve data to use in constructing the
 * activity instance.
 * @param manifest manifest file JSON
 * @param fn the creation function to use
 */
export function registerCreationFunc(manifest: Manifest, fn: creationFn) {
  if (window.oliCreationFuncs === undefined) {
    window.oliCreationFuncs = {};
  }

  window.oliCreationFuncs[manifest.id] = fn;
}

export function invokeCreationFunc(
  id: string,
  context: ResourceContext,
): Promise<ActivityModelSchema> {
  console.log(window.oliCreationFuncs);

  if (window.oliCreationFuncs !== undefined) {
    const fn = window.oliCreationFuncs[id];
    if (typeof fn === 'function') {
      return fn.apply(undefined, [context]);
    }
  }
  return Promise.reject('could not invoke creation function for ' + id);
}

declare global {
  interface Window {
    oliCreationFuncs: Record<string, any>;
  }
}
