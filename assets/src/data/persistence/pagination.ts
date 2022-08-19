import * as Extrinsic from './extrinsic';
import { SectionSlug } from 'data/types';

export function updatePaginationState(
  slug: SectionSlug,
  attemptGuid: string,
  forId: string,
  index: number[],
) {
  // At the moment adding an entry to a list that is a value of a key is a multi step operation,
  // that involves two server requests:
  //
  // 1. Fetch the key-value (server request 1)
  // 2. Client-side append the value to the list (if the key even exists)
  // 3. Upsert the new key-value (server request 2)
  return new Promise((resolve, reject) => {
    return Extrinsic.readAttempt(slug, attemptGuid, ['paginationState']).then((result: any) => {
      if ((result as any).type !== undefined && (result as any).type === 'ServerError') {
        reject(result);
      } else {
        let update: any = { paginationState: {} };
        update.paginationState[forId + ''] = [0, ...index];

        if (result['paginationState'] !== undefined) {
          const existingValue = (result['paginationState'] as any)[forId + ''];
          if (existingValue !== undefined) {
            result.paginationState[forId + ''] = [...existingValue, ...index];
            update = result;
          } else {
            result.paginationState[forId + ''] = [0, ...index];
            update = result;
          }
        }

        Extrinsic.upsertAttempt(slug, attemptGuid, update).then((result) => {
          if ((result as any).type !== undefined && (result as any).type === 'ServerError') {
            reject(result);
          } else {
            resolve(result);
          }
        });
      }
    });
  });
}
