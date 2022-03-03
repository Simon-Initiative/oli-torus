import { Maybe } from 'tsmonad';

interface SurfaceAttribute {
  type: string;
  data: any;
}

interface SurfaceEvent {
  name: string;
  target: string;
}

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

export const maybePushEvent = (
  hook: any,
  event_str_or_obj: Maybe<string | SurfaceEvent>,
  params?: any,
  onReply?: any,
) => {
  event_str_or_obj.lift((e) => {
    if (typeof e === 'string') {
      return hook.pushEvent(e, params, onReply);
    } else if (e.target === 'live_view') {
      return hook.pushEvent(e.name, params, onReply);
    } else {
      return hook.pushEventTo(e.target, e.name, params, onReply);
    }
  });
};
