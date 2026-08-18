import { useCallback, useEffect, useRef, useState } from 'react';
import { ParsedFrame, decompressFrames, parseGIF } from 'gifuct-js';

const GIF_EXTENSION_REGEX = /\.gif(?:[?#].*)?$/i;

export function isGifSrc(url?: string): boolean {
  return !!url && GIF_EXTENSION_REGEX.test(url.trim());
}

interface UseGifPlayerOptions {
  autoPlay?: boolean;
  respectReducedMotion?: boolean;
}

type Status = 'idle' | 'loading' | 'ready' | 'error';

export function useGifPlayer(src: string, options: UseGifPlayerOptions = {}) {
  const { autoPlay = true, respectReducedMotion = true } = options;

  const canvasRef = useRef<HTMLCanvasElement>(null);
  const patchCanvasRef = useRef<HTMLCanvasElement | null>(null);
  const framesRef = useRef<ParsedFrame[]>([]);
  const frameIndexRef = useRef(0);
  const rafRef = useRef<number | undefined>(undefined);
  const lastTickRef = useRef(0);
  const snapshotRef = useRef<ImageData | null>(null);
  const isPlayingRef = useRef(false);

  const [isPlaying, setIsPlaying] = useState(false);
  const [status, setStatus] = useState<Status>('idle');
  const [dimensions, setDimensions] = useState<{ width: number; height: number } | null>(null);

  const getPatchCanvas = useCallback(() => {
    if (!patchCanvasRef.current) {
      patchCanvasRef.current = document.createElement('canvas');
    }
    return patchCanvasRef.current;
  }, []);

  const drawFrame = useCallback(
    (index: number, applyPreviousDisposal: boolean) => {
      const ctx = canvasRef.current?.getContext('2d');
      const frames = framesRef.current;
      const frame = frames[index];
      if (!ctx || !frame) return;

      if (applyPreviousDisposal && index > 0) {
        const prevFrame = frames[index - 1];
        if (prevFrame) {
          if (prevFrame.disposalType === 2) {
            ctx.clearRect(
              prevFrame.dims.left,
              prevFrame.dims.top,
              prevFrame.dims.width,
              prevFrame.dims.height,
            );
          } else if (prevFrame.disposalType === 3 && snapshotRef.current) {
            ctx.putImageData(snapshotRef.current, 0, 0);
          }
        }
      }

      if (frame.disposalType === 3) {
        snapshotRef.current = ctx.getImageData(0, 0, ctx.canvas.width, ctx.canvas.height);
      }

      const { width, height, left, top } = frame.dims;
      const patchCanvas = getPatchCanvas();
      patchCanvas.width = width;
      patchCanvas.height = height;
      const patchCtx = patchCanvas.getContext('2d');
      if (!patchCtx) return;

      const imageData = patchCtx.createImageData(width, height);
      imageData.data.set(frame.patch);
      patchCtx.putImageData(imageData, 0, 0);
      ctx.drawImage(patchCanvas, left, top);
    },
    [getPatchCanvas],
  );

  const stop = useCallback(() => {
    if (rafRef.current !== undefined) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = undefined;
    }
    isPlayingRef.current = false;
    setIsPlaying(false);
  }, []);

  const play = useCallback(() => {
    if (framesRef.current.length <= 1) return;
    if (isPlayingRef.current) return;

    isPlayingRef.current = true;
    setIsPlaying(true);
    lastTickRef.current = performance.now();

    const loop = (now: number) => {
      if (!isPlayingRef.current) return;

      const frames = framesRef.current;
      const delay = Math.max(frames[frameIndexRef.current]?.delay || 100, 20);
      if (now - lastTickRef.current >= delay) {
        frameIndexRef.current = (frameIndexRef.current + 1) % frames.length;
        drawFrame(frameIndexRef.current, true);
        lastTickRef.current = now;
      }
      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);
  }, [drawFrame]);

  const toggle = useCallback(() => (isPlayingRef.current ? stop() : play()), [play, stop]);

  useEffect(() => {
    let cancelled = false;
    setStatus('loading');
    frameIndexRef.current = 0;
    snapshotRef.current = null;
    stop();

    (async () => {
      try {
        const res = await fetch(src, { mode: 'cors', credentials: 'omit' });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const buffer = await res.arrayBuffer();
        if (cancelled) return;

        const gif = parseGIF(buffer);
        const frames = decompressFrames(gif, true);
        if (!frames.length) throw new Error('No frames decoded');
        framesRef.current = frames;

        const width = gif.lsd.width;
        const height = gif.lsd.height;
        setDimensions({ width, height });

        const canvas = canvasRef.current;
        if (!canvas) return;
        canvas.width = width;
        canvas.height = height;

        drawFrame(0, false);
        setStatus('ready');

        const prefersReducedMotion =
          respectReducedMotion &&
          typeof window !== 'undefined' &&
          window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;

        if (autoPlay && !prefersReducedMotion) {
          play();
        }
      } catch (err) {
        if (!cancelled) {
          // eslint-disable-next-line no-console
          console.warn('[useGifPlayer] could not decode GIF (possibly a CORS issue):', err);
          setStatus('error');
        }
      }
    })();

    return () => {
      cancelled = true;
      stop();
    };
    // Re-decode only when src changes; play/stop/draw are stable enough for this lifecycle.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [src]);

  return { canvasRef, isPlaying, toggle, status, dimensions };
}
