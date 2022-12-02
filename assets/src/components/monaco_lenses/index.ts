import { activityLinksLens } from './activity_links_lens';

export function registry(name: string) {
  switch (name) {
    case 'activity-links':
      return activityLinksLens;
    default:
      throw `Unknown monaco code lens '${name}'`;
  }
}
