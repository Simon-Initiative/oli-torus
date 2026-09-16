import React, { useCallback, useLayoutEffect, useRef, useState } from 'react';
import { Quill } from 'react-quill';
import { MAX_IMAGE_DIMENSION, normalizeImageDimension } from './imageSizing';

export interface QuillImageResizeProps {
  editor: any;
  image: HTMLImageElement;
  container: HTMLElement;
  onEdit: () => void;
  onDeselect: () => void;
}

type ImageSize = { width: number; height: number };
type ImageBounds = ImageSize & { left: number; top: number };
type ResizeAxis = 'width' | 'height' | 'both';
const previewProperties = ['width', 'height', 'aspectRatio'] as const;
type ImageDrag = {
  pointerId: number;
  handle: HTMLButtonElement;
  axis: ResizeAxis;
  startX: number;
  startY: number;
  startSize: ImageSize;
  size: ImageSize;
  ratio?: number;
  originalStyles: {
    property: typeof previewProperties[number];
    value: string;
    priority: string;
  }[];
};

const roundedSize = (value: number) => Math.max(1, Math.round(value));

// Scale both dimensions together to keep linked dimensions within the supported bounds.
const proportionalSize = (
  width: number,
  ratio: number,
  maximumWidth = MAX_IMAGE_DIMENSION,
): ImageSize => {
  const height = width / ratio;
  const scale = Math.min(1, maximumWidth / width, MAX_IMAGE_DIMENSION / height);
  return { width: roundedSize(width * scale), height: roundedSize(height * scale) };
};

/** Edits image dimensions with one undoable Quill format change per completed resize. */
export const QuillImageResize: React.FC<QuillImageResizeProps> = ({
  editor,
  image,
  container,
  onEdit,
  onDeselect,
}) => {
  const [bounds, setBounds] = useState<ImageBounds>({ left: 0, top: 0, width: 0, height: 0 });
  const [widthDraft, setWidthDraft] = useState('');
  const [heightDraft, setHeightDraft] = useState('');
  const [preserveProportions, setPreserveProportions] = useState(true);
  const [ratio, setRatio] = useState<number | undefined>();
  const [invalidSize, setInvalidSize] = useState(false);
  const locked = useRef(true);
  const drag = useRef<ImageDrag | null>(null);
  const frame = useRef<number | null>(null);
  const onDeselectRef = useRef(onDeselect);
  onDeselectRef.current = onDeselect;

  const isAttached = useCallback(
    () => image.isConnected && container.contains(image) && editor.root.contains(image),
    [container, editor, image],
  );

  const readRatio = useCallback(() => {
    if (image.naturalWidth > 0 && image.naturalHeight > 0)
      return image.naturalWidth / image.naturalHeight;
    // Before loading, a nonzero rectangle may be an alt-text placeholder, not the image ratio.
    return undefined;
  }, [image]);

  const syncDrafts = useCallback(
    (updateLock = false) => {
      const nextRatio = readRatio();
      const rect = image.getBoundingClientRect();
      const width = normalizeImageDimension(image.getAttribute('width')) ?? rect.width;
      const height =
        normalizeImageDimension(image.getAttribute('height')) ??
        (nextRatio && width > 0 ? width / nextRatio : rect.height);
      setRatio(nextRatio);
      setWidthDraft(width > 0 ? String(roundedSize(width)) : '');
      setHeightDraft(height > 0 ? String(roundedSize(height)) : '');
      if (updateLock) {
        locked.current = !normalizeImageDimension(image.getAttribute('height'));
        setPreserveProportions(locked.current);
      }
    },
    [image, readRatio],
  );

  const restoreDrag = useCallback(() => {
    const current = drag.current;
    if (!current) return;
    drag.current = null;
    current.originalStyles.forEach(({ property, value, priority }) => {
      image.style[property] = value;
      if (priority) {
        image.style.setProperty(
          property === 'aspectRatio' ? 'aspect-ratio' : property,
          value,
          priority,
        );
      }
    });
    if (current.handle.hasPointerCapture?.(current.pointerId))
      current.handle.releasePointerCapture(current.pointerId);
  }, [image]);

  const dismissControls = useCallback(() => {
    restoreDrag();
    if (isAttached()) image.focus({ preventScroll: true });
    onDeselectRef.current();
  }, [image, isAttached, restoreDrag]);

  const measure = useCallback(() => {
    if (!isAttached()) {
      restoreDrag();
      onDeselectRef.current();
      return;
    }
    const imageRect = image.getBoundingClientRect();
    const containerRect = container.getBoundingClientRect();
    const next = {
      left: imageRect.left - containerRect.left - container.clientLeft + container.scrollLeft,
      top: imageRect.top - containerRect.top - container.clientTop + container.scrollTop,
      width: imageRect.width,
      height: imageRect.height,
    };
    setBounds((previous) =>
      previous.left === next.left &&
      previous.top === next.top &&
      previous.width === next.width &&
      previous.height === next.height
        ? previous
        : next,
    );
  }, [container, image, isAttached, restoreDrag]);

  const scheduleMeasure = useCallback(() => {
    if (frame.current !== null) return;
    frame.current = window.requestAnimationFrame(() => {
      frame.current = null;
      measure();
    });
  }, [measure]);

  useLayoutEffect(() => {
    syncDrafts(true);
    setInvalidSize(false);
    measure();
    const handleTextChange = () => {
      // Undo, deletion, or an external edit can replace the selected image during a drag.
      restoreDrag();
      syncDrafts(true);
      scheduleMeasure();
    };
    const handleImageLoad = () => {
      syncDrafts();
      scheduleMeasure();
    };
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      event.stopPropagation();
      dismissControls();
    };
    const observer =
      typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(scheduleMeasure);
    observer?.observe(image);
    observer?.observe(container);
    image.addEventListener('load', handleImageLoad);
    container.addEventListener('keydown', handleEscape, true);
    container.addEventListener('scroll', scheduleMeasure, true);
    window.addEventListener('scroll', scheduleMeasure, true);
    window.addEventListener('resize', scheduleMeasure);
    editor.on('text-change', handleTextChange);
    return () => {
      restoreDrag();
      observer?.disconnect();
      image.removeEventListener('load', handleImageLoad);
      container.removeEventListener('keydown', handleEscape, true);
      container.removeEventListener('scroll', scheduleMeasure, true);
      window.removeEventListener('scroll', scheduleMeasure, true);
      window.removeEventListener('resize', scheduleMeasure);
      editor.off('text-change', handleTextChange);
      if (frame.current !== null) {
        window.cancelAnimationFrame(frame.current);
        frame.current = null;
      }
    };
  }, [
    container,
    dismissControls,
    editor,
    image,
    measure,
    restoreDrag,
    scheduleMeasure,
    syncDrafts,
  ]);

  // Toolbar wrapping and its loading/error messages can move the image without resizing it.
  useLayoutEffect(measure, [measure, preserveProportions, ratio, invalidSize]);

  const commitSize = (width: number | false, height: number | false) => {
    restoreDrag();
    if (!isAttached()) {
      onDeselectRef.current();
      return;
    }
    const blot = Quill.find(image);
    if (!blot) {
      onDeselectRef.current();
      return;
    }
    const index = editor.getIndex(blot);
    if (index < 0) return;
    const history = editor.getModule('history');
    history?.cutoff();
    editor.formatText(
      index,
      1,
      {
        width: width === false ? false : String(width),
        height: height === false ? false : String(height),
      },
      'user',
    );
    history?.cutoff();
    syncDrafts(true);
    setInvalidSize(false);
    scheduleMeasure();
  };

  const changeDimension = (axis: 'width' | 'height', value: string) => {
    setInvalidSize(false);
    if (axis === 'width') setWidthDraft(value);
    else setHeightDraft(value);
    const dimension = normalizeImageDimension(value);
    if (!locked.current || !ratio || dimension === undefined) return;
    const size = proportionalSize(axis === 'width' ? dimension : dimension * ratio, ratio);
    setWidthDraft(String(size.width));
    setHeightDraft(String(size.height));
  };

  const applySize = () => {
    const width = normalizeImageDimension(widthDraft);
    const height = normalizeImageDimension(heightDraft);
    if (width === undefined || ((!locked.current || ratio) && height === undefined)) {
      setInvalidSize(true);
      return;
    }
    const size =
      locked.current && ratio
        ? proportionalSize(width, ratio)
        : { width: roundedSize(width), height: height ? roundedSize(height) : 0 };
    commitSize(size.width, locked.current ? false : size.height);
  };

  const changeProportions = (checked: boolean) => {
    restoreDrag();
    locked.current = checked;
    setPreserveProportions(checked);
    setInvalidSize(false);
    if (checked) {
      // Removing only height restores the source image's ratio, not its stretched display ratio.
      commitSize(normalizeImageDimension(image.getAttribute('width')) ?? false, false);
    }
  };

  const startDrag = (event: React.PointerEvent<HTMLButtonElement>, axis: ResizeAxis) => {
    if (event.button !== 0 || !isAttached() || (locked.current && !ratio)) return;
    event.preventDefault();
    event.stopPropagation();
    event.currentTarget.focus();
    const rect = image.getBoundingClientRect();
    const size = { width: rect.width, height: rect.height };
    drag.current = {
      pointerId: event.pointerId,
      handle: event.currentTarget,
      axis,
      startX: event.clientX,
      startY: event.clientY,
      startSize: size,
      size,
      ratio: locked.current ? ratio : undefined,
      originalStyles: previewProperties.map((property) => ({
        property,
        value: image.style[property] || '',
        priority: image.style.getPropertyPriority(
          property === 'aspectRatio' ? 'aspect-ratio' : property,
        ),
      })),
    };
    event.currentTarget.setPointerCapture(event.pointerId);
    setInvalidSize(false);
  };

  const previewDrag = (event: React.PointerEvent<HTMLButtonElement>) => {
    const current = drag.current;
    if (!current || current.pointerId !== event.pointerId) return;
    event.preventDefault();
    const availableWidth = container.clientWidth - Math.max(0, bounds.left - container.scrollLeft);
    const maximumWidth =
      availableWidth > 0 ? Math.min(availableWidth, MAX_IMAGE_DIMENSION) : MAX_IMAGE_DIMENSION;
    const dx = event.clientX - current.startX;
    const dy = event.clientY - current.startY;
    if (current.ratio) {
      const fromHeight =
        current.axis === 'height' ||
        (current.axis === 'both' &&
          Math.abs(dy / current.startSize.height) > Math.abs(dx / current.startSize.width));
      const width = fromHeight
        ? (current.startSize.height + dy) * current.ratio
        : current.startSize.width + dx;
      current.size = proportionalSize(Math.max(1, width), current.ratio, maximumWidth);
    } else {
      current.size = {
        width: roundedSize(
          Math.min(maximumWidth, current.startSize.width + (current.axis === 'height' ? 0 : dx)),
        ),
        height: roundedSize(
          Math.min(
            MAX_IMAGE_DIMENSION,
            current.startSize.height + (current.axis === 'width' ? 0 : dy),
          ),
        ),
      };
    }
    // Image formats read attributes: temporary styles preview without adding history entries.
    image.style.width = `${current.size.width}px`;
    image.style.height = 'auto';
    image.style.aspectRatio = `${current.size.width} / ${current.size.height}`;
    setWidthDraft(String(current.size.width));
    setHeightDraft(String(current.size.height));
    scheduleMeasure();
  };

  const endDrag = (event: React.PointerEvent<HTMLButtonElement>) => {
    const current = drag.current;
    if (!current || current.pointerId !== event.pointerId) return;
    event.preventDefault();
    const { size, startSize, ratio: originalRatio } = current;
    restoreDrag();
    if (size.width !== startSize.width || size.height !== startSize.height)
      commitSize(size.width, originalRatio ? false : size.height);
    scheduleMeasure();
  };

  const cancelDrag = () => {
    restoreDrag();
    syncDrafts();
    scheduleMeasure();
  };

  const canDrag = bounds.width > 0 && bounds.height > 0 && (!preserveProportions || Boolean(ratio));
  const handleProps = {
    type: 'button' as const,
    disabled: !canDrag,
    onPointerMove: previewDrag,
    onPointerUp: endDrag,
    onPointerCancel: cancelDrag,
    onLostPointerCapture: cancelDrag,
  };
  const dimensionKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      applySize();
    }
  };

  return (
    <>
      <div
        data-quill-image-controls
        className="pointer-events-none absolute z-20 border-2 border-blue-600"
        style={bounds}
      >
        <button
          {...handleProps}
          aria-label="Resize image width"
          title="Drag left or right to resize"
          className="pointer-events-auto absolute -right-3 top-1/2 flex h-6 w-6 -translate-y-1/2 touch-none cursor-ew-resize items-center justify-center rounded border-2 border-white bg-blue-600 text-white shadow focus:ring-2 focus:ring-blue-800 disabled:opacity-50"
          onPointerDown={(event) => startDrag(event, 'width')}
        >
          <span aria-hidden="true">↔</span>
        </button>
        <button
          {...handleProps}
          aria-label="Resize image height"
          title="Drag up or down to resize"
          className="pointer-events-auto absolute -bottom-3 left-1/2 flex h-6 w-6 -translate-x-1/2 touch-none cursor-ns-resize items-center justify-center rounded border-2 border-white bg-blue-600 text-white shadow focus:ring-2 focus:ring-blue-800 disabled:opacity-50"
          onPointerDown={(event) => startDrag(event, 'height')}
        >
          <span aria-hidden="true">↕</span>
        </button>
        <button
          {...handleProps}
          aria-label="Resize image handle"
          title="Drag this corner to resize"
          className="pointer-events-auto absolute -bottom-3 -right-3 flex h-7 w-7 touch-none cursor-nwse-resize items-center justify-center rounded border-2 border-white bg-blue-600 text-lg text-white shadow focus:ring-2 focus:ring-blue-800 disabled:opacity-50"
          onPointerDown={(event) => startDrag(event, 'both')}
        >
          <span aria-hidden="true">↘</span>
        </button>
      </div>
      <div
        data-quill-image-controls
        role="group"
        aria-label="Image controls"
        className="sticky top-0 z-30 order-first flex w-full shrink-0 flex-wrap items-center gap-2 rounded border border-gray-300 bg-white p-2 text-sm text-gray-900 shadow-md"
        onPointerDown={(event) => event.stopPropagation()}
      >
        <label className="flex items-center gap-2">
          Image width (px)
          <input
            type="number"
            min={1}
            max={MAX_IMAGE_DIMENSION}
            step={1}
            value={widthDraft}
            aria-invalid={invalidSize}
            className="w-20 rounded border border-gray-400 px-2 py-1 text-gray-900"
            onChange={(event) => changeDimension('width', event.target.value)}
            onKeyDown={dimensionKeyDown}
          />
        </label>
        <label className="flex items-center gap-2">
          Image height (px)
          <input
            type="number"
            min={1}
            max={MAX_IMAGE_DIMENSION}
            step={1}
            value={heightDraft}
            disabled={preserveProportions && !ratio}
            aria-invalid={invalidSize}
            className="w-20 rounded border border-gray-400 px-2 py-1 text-gray-900 disabled:opacity-50"
            onChange={(event) => changeDimension('height', event.target.value)}
            onKeyDown={dimensionKeyDown}
          />
        </label>
        <label className="flex items-center gap-2">
          <input
            type="checkbox"
            checked={preserveProportions}
            onChange={(event) => changeProportions(event.target.checked)}
          />
          Keep original proportions
        </label>
        <button
          type="button"
          className="rounded bg-blue-600 px-2 py-1 text-white"
          onClick={applySize}
        >
          Apply size
        </button>
        <button
          type="button"
          className="rounded border border-gray-400 px-2 py-1"
          onClick={() => commitSize(false, false)}
        >
          Full width
        </button>
        <button type="button" className="rounded border border-gray-400 px-2 py-1" onClick={onEdit}>
          Edit image
        </button>
        <button
          type="button"
          className="rounded border border-gray-400 px-2 py-1"
          onClick={dismissControls}
        >
          Close image controls
        </button>
        <span className="w-full text-xs text-gray-600">
          Drag a side or corner handle, or enter dimensions.
        </span>
        {preserveProportions && !ratio && (
          <span role="status">Image proportions will be available after the image loads.</span>
        )}
        {invalidSize && (
          <span role="alert">Enter dimensions from 1 to {MAX_IMAGE_DIMENSION} pixels.</span>
        )}
      </div>
    </>
  );
};
