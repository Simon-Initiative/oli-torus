import { SectionSlug } from 'data/types';
import * as Extrinsic from './extrinsic';

export function updateAlternativesPreference(
  slug: SectionSlug,
  alternativesId: number,
  value: string,
) {
  return new Promise((resolve, reject) => {
    return Extrinsic.upsertSection(slug, { [`alt_pref_${alternativesId}`]: value }).then(
      (result) => {
        if ((result as any).type !== undefined && (result as any).type === 'ServerError') {
          reject(result);
        } else {
          resolve(result);
        }
      },
    );
  });
}
