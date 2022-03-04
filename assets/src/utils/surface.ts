import { Hooks } from 'hooks';
import { Maybe } from 'tsmonad';

interface SurfaceAttribute {
  type: string;
  data: any;
}

type SurfaceEvent =
  | string
  | {
      name: string;
      target: string;
    };

export const getAttribute = (hook: any, name: string) =>
  maybeGetAttribute(hook, name).valueOrThrow(
    Error(`Undefined attribute '${name}' in surface component hook`),
  );

export const maybeGetAttribute = (hook: any, name: string) =>
  Maybe.maybe(hook.el.getAttribute(name)).map((attr) => {
    // if data is encoded as a javascript object, then parse it. Otherwise, treat it as a string
    attr = JSON.parse(attr) as SurfaceAttribute;

    return attr.type === 'string' ? attr.data : JSON.parse(attr.data);
  });

export const maybeHandleEvent = (
  hook: any,
  event: Maybe<SurfaceEvent>,
  handle_fn: (params: any) => any,
) => {
  event.lift((e) => {
    if (typeof e === 'string') {
      return hook.handleEvent(e, handle_fn);
    } else {
      return hook.handleEvent(e.name, handle_fn);
    }
  });
};

export const maybePushEvent = (
  hook: any,
  event: Maybe<SurfaceEvent>,
  params?: any,
  onReply?: any,
) => {
  event.lift((e) => {
    if (typeof e === 'string') {
      return hook.pushEvent(e, params, onReply);
    } else if (e.target === 'live_view') {
      return hook.pushEvent(e.name, params, onReply);
    } else {
      return hook.pushEventTo(e.target, e.name, params, onReply);
    }
  });
};

export const surfaceHook = (hook: any) => {
  hook.getAttribute = (name: string) => getAttribute(hook, name);
  hook.maybeGetAttribute = (name: string) => maybeGetAttribute(hook, name);
  hook.maybeHandleEvent = (event: Maybe<SurfaceEvent>, handle_fn: (params: any) => any) =>
    maybeHandleEvent(hook, event, handle_fn);
  hook.maybePushEvent = (event: Maybe<SurfaceEvent>, params?: any, onReply?: any) =>
    maybePushEvent(hook, event, params, onReply);

  return hook;
};
