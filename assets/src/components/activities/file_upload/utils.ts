import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { FileUploadSchema, FileSpec } from 'components/activities/file_upload/schema';
import { Responses } from 'data/activities/model/responses';
import { GradingApproach, makeHint, makeStem, ScoringStrategy } from '../types';

export const defaultModel: () => FileUploadSchema = () => {
  return {
    stem: makeStem(''),
    fileSpec: createDefaultFileSpec(),
    authoring: {
      parts: [
        {
          id: DEFAULT_PART_ID,
          scoringStrategy: ScoringStrategy.average,
          gradingApproach: GradingApproach.manual,
          responses: Responses.forTextInput(),
          hints: [makeHint(''), makeHint(''), makeHint('')],
        },
      ],
      transformations: [],
      previewText: '',
    },
  };
};

export const defaultMaxFileSize = 1024 * 1000 * 10; // 10 MB

export const createDefaultFileSpec: () => FileSpec = () =>
  ({
    maxCount: 1,
    accept: '',
    maxSizeInBytes: defaultMaxFileSize,
  } as FileSpec);

export function fileName(url: string) {
  return url.substring(url.lastIndexOf('/') + 1);
}

export function toDate(ms: number) {
  const date = new Date(ms);
  return date.toLocaleString();
}

export function getReadableFileSizeString(fileSizeInBytes: number) {
  let i = -1;
  const byteUnits = [' kB', ' MB', ' GB', ' TB', 'PB', 'EB', 'ZB', 'YB'];
  do {
    fileSizeInBytes = fileSizeInBytes / 1024;
    i++;
  } while (fileSizeInBytes > 1024);

  return Math.max(fileSizeInBytes, 0.1).toFixed(1) + byteUnits[i];
}
