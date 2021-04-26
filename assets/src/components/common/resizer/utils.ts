import * as elementResizeDetectorMaker from 'element-resize-detector';
import * as shallowequal from 'shallowequal';
import { once } from 'lodash';

import { Size } from './types';

// export function without<T>(list: T[], toRemove: T[]): T[] {
//   if (Array.isArray(list) && Array.isArray(toRemove)) {
//     const toRemoveMemo = toRemove.reduce((acc, curr) => acc[curr] = true, {});
//     return list.filter(x => toRemoveMemo[x] ? false : true);
//   }
//   // if is object
//   if (typeof list === 'object' && list !== null && typeof toRemove === 'object' && toRemove !== null) {
//     return [];
//   }
//   return list;
// }

export function getSize(element: HTMLElement): Size {
  return {
    height: element.clientHeight,
    width: element.clientWidth,
  };
}

export function isHeightChanged(sizeA: Size | null, sizeB: Size | null): boolean {
  if (sizeA && sizeB) {
    return sizeA.height !== sizeB.height;
  } else {
    return true;
  }
}

export function isWidthChanged(sizeA: Size | null, sizeB: Size | null): boolean {
  if (sizeA && sizeB) {
    return sizeA.width !== sizeB.width;
  } else {
    return true;
  }
}

function compareDataset(
  currentValue: any,
  nextValue: any,
  key?: string | number,
) {
  if (key !== undefined) {
    return String(currentValue) === String(nextValue);
  } else {
    return undefined;
  }
}

export function updateElementDataAttributes(
  element: HTMLElement,
  dataset: DOMStringMap,
): void {
  const currentDataset = element.dataset;
  const nextDataset = { ...dataset };

  if (!shallowequal(currentDataset, nextDataset, compareDataset)) {
    Object.keys(currentDataset).forEach((key) => {
      if (currentDataset[key] !== nextDataset[key]) {
        currentDataset[key] = nextDataset[key];
      }
      delete nextDataset[key];
    });

    Object.keys(nextDataset).forEach((key) => {
      currentDataset[key] = nextDataset[key];
    });
  }
}

export const getResizeDetector = once(() => elementResizeDetectorMaker({ strategy: 'scroll' }));