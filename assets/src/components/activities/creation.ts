import { Manifest, ActivityModelSchema, CreationContext } from './types';
import { ResourceContext } from 'data/content/resource';

export type creationFn = (context: CreationContext) => Promise<ActivityModelSchema>;

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
