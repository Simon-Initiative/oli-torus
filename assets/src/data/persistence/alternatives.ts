import * as Extrinsic from './extrinsic';
import { SectionSlug } from 'data/types';

export function updateAlternativesPreference(slug: SectionSlug, prefName: string, value: string) {
  return new Promise((resolve, reject) => {
    return Extrinsic.upsertSection(slug, { [`alt_pref_${prefName}`]: value }).then((result) => {
      if ((result as any).type !== undefined && (result as any).type === 'ServerError') {
        reject(result);
      } else {
        resolve(result);
      }
    });
  });
}
