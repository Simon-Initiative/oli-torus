import { expect, type Locator } from '@playwright/test';

/**
 * Student delivery helpers for image hotspot activities.
 *
 * These helpers encapsulate image-map specific interactions that are awkward
 * to express directly in Playwright specs, such as resolving <area> coords
 * into click positions on the rendered image.
 */

/**
 * Clicks an image-map hotspot by its title by translating the <area> coords
 * into a rendered-image click position. This avoids relying on direct clicks
 * against <area>, which tend to be flaky in browser automation.
 */
export async function clickImageHotspot(activity: Locator, title: string) {
  const area = activity.getByTitle(title, { exact: true }).first();
  const image = activity.locator('img[usemap]').first();

  await expect(area).toBeAttached();
  await expect(image).toBeVisible();

  const hotspot = await area.evaluate((node) => {
    const areaElement = node as HTMLAreaElement;

    return {
      shape: areaElement.shape,
      coords: areaElement.coords.split(',').map((value) => Number(value.trim())),
    };
  });

  const imageMetrics = await image.evaluate((node) => {
    const imageElement = node as HTMLImageElement;
    const bounds = imageElement.getBoundingClientRect();

    return {
      renderedWidth: bounds.width,
      renderedHeight: bounds.height,
      naturalWidth: imageElement.naturalWidth || bounds.width,
      naturalHeight: imageElement.naturalHeight || bounds.height,
    };
  });

  const clickPoint = hotspotCenter(hotspot.shape, hotspot.coords);
  const xScale = imageMetrics.renderedWidth / imageMetrics.naturalWidth;
  const yScale = imageMetrics.renderedHeight / imageMetrics.naturalHeight;

  await image.click({
    position: {
      x: clamp(clickPoint.x * xScale, 1, imageMetrics.renderedWidth - 1),
      y: clamp(clickPoint.y * yScale, 1, imageMetrics.renderedHeight - 1),
    },
  });
}

function hotspotCenter(shape: string, coords: number[]) {
  switch (shape) {
    case 'circle': {
      const [cx, cy] = coords;
      return { x: cx, y: cy };
    }

    case 'poly': {
      const points = [];

      for (let i = 0; i < coords.length; i += 2) {
        points.push({ x: coords[i], y: coords[i + 1] });
      }

      const x = points.reduce((sum, point) => sum + point.x, 0) / points.length;
      const y = points.reduce((sum, point) => sum + point.y, 0) / points.length;

      return { x, y };
    }

    case 'rect':
    default: {
      const [left, top, right, bottom] = coords;
      return { x: (left + right) / 2, y: (top + bottom) / 2 };
    }
  }
}

function clamp(value: number, min: number, max: number) {
  return Math.min(Math.max(value, min), max);
}
