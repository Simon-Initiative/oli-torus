import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ArrowContainer, Popover } from 'react-tiny-popover';
import type { ContentLocation, PopoverState } from 'react-tiny-popover';
import { Popup as PopupModel } from 'data/content/model/elements/types';
import { usePointerCapability } from 'hooks/use_pointer_capability';
import guid from 'utils/guid';
import { isEmptyContent } from '../../data/content/utils';
import { useAudio } from '../hooks/useAudio';

const POPUP_OPEN_EVENT = 'key-notion-popup-open';
const POPUP_HIDE_DELAY_MS = 300;
const POPUP_ARROW_SIZE = 10;

// Extracts plain text from arbitrary React nodes for use in aria labels.
const extractTextFromNode = (node: React.ReactNode): string => {
  if (node === null || node === undefined || typeof node === 'boolean') {
    return '';
  }

  if (typeof node === 'string' || typeof node === 'number') {
    return String(node);
  }

  if (Array.isArray(node)) {
    return node.map(extractTextFromNode).join('');
  }

  if (React.isValidElement(node)) {
    return extractTextFromNode(node.props.children);
  }

  return '';
};

interface Props {
  children: React.ReactNode;
  popupContent: React.ReactNode;
  popup: PopupModel;
}

export const Popup: React.FC<Props> = ({ children, popupContent, popup }) => {
  const { audioPlayer, playAudio, pauseAudio, isPlaying } = useAudio(popup.audioSrc);
  const { canHover, isCoarsePointer } = usePointerCapability();
  const hasAudio = Boolean(popup.audioSrc);
  const instanceId = useMemo(() => guid(), []);
  const popoverId = useMemo(() => `key-notion-popup-${instanceId}`, [instanceId]);

  const hoverTriggered = popup.trigger === 'hover';
  const usesHoverInteraction = hoverTriggered && canHover && !isCoarsePointer;
  const usesTapInteraction = hoverTriggered && (!canHover || isCoarsePointer);

  const hideTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const anchorRef = useRef<HTMLSpanElement | null>(null);
  const [isPopoverOpen, setIsPopoverOpen] = useState(false);
  const [scrollContainer, setScrollContainer] = useState<HTMLElement | null>(null);
  const anchorLabel = useMemo(() => {
    const label = extractTextFromNode(children).trim();

    // Capitalize the first character for a clean aria-friendly label.
    return label.charAt(0).toUpperCase() + label.slice(1);
  }, [children]);
  const headingId = anchorLabel ? `${popoverId}-heading` : undefined;

  const findScrollContainer = useCallback(() => {
    const anchor = anchorRef.current;
    if (!anchor || typeof window === 'undefined') {
      return null;
    }

    const doc = anchor.ownerDocument;
    let current: HTMLElement | null = anchor.parentElement;

    while (current && current !== doc.body && current !== doc.documentElement) {
      const style = window.getComputedStyle(current);
      const overflowValues = [style.overflowY, style.overflowX];
      const isScrollable = ['auto', 'scroll', 'overlay'].some((overflow) =>
        overflowValues.includes(overflow),
      );

      if (isScrollable) {
        return current;
      }

      current = current.parentElement;
    }

    return null;
  }, []);

  const clearHideTimeout = useCallback(() => {
    if (hideTimeoutRef.current) {
      clearTimeout(hideTimeoutRef.current);
      hideTimeoutRef.current = null;
    }
  }, []);

  const preparePopover = useCallback(() => {
    const container = findScrollContainer();
    setScrollContainer((previous) => (previous === container ? previous : container));
  }, [findScrollContainer]);

  const startAudioIfNeeded = useCallback(
    (event: React.SyntheticEvent) => {
      if (hasAudio && !isPlaying) {
        playAudio(event);
      }
    },
    [hasAudio, isPlaying, playAudio],
  );

  const toggleAudioPlayback = useCallback(
    (event: React.SyntheticEvent) => {
      if (!hasAudio) {
        return;
      }

      if (isPlaying) {
        pauseAudio();
      } else {
        playAudio(event);
      }
    },
    [hasAudio, isPlaying, pauseAudio, playAudio],
  );

  const emitOpenEvent = useCallback(() => {
    if (typeof window === 'undefined') {
      return;
    }

    window.dispatchEvent(
      new CustomEvent<{ id: string }>(POPUP_OPEN_EVENT, {
        detail: { id: instanceId },
      }),
    );
  }, [instanceId]);

  const openPopover = useCallback(() => {
    preparePopover();
    clearHideTimeout();
    setIsPopoverOpen((alreadyOpen) => {
      if (!alreadyOpen) {
        emitOpenEvent();
      }
      return true;
    });
  }, [preparePopover, clearHideTimeout, emitOpenEvent]);

  const closePopover = useCallback(() => {
    clearHideTimeout();
    setIsPopoverOpen(false);
    pauseAudio();
  }, [clearHideTimeout, pauseAudio]);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return undefined;
    }

    const handleExternalOpen = (event: Event) => {
      const customEvent = event as CustomEvent<{ id: string }>;
      if (customEvent.detail?.id === instanceId) {
        return;
      }

      clearHideTimeout();
      setIsPopoverOpen(false);
      pauseAudio();
    };

    window.addEventListener(POPUP_OPEN_EVENT, handleExternalOpen as EventListener);

    return () => {
      window.removeEventListener(POPUP_OPEN_EVENT, handleExternalOpen as EventListener);
    };
  }, [clearHideTimeout, instanceId, pauseAudio]);

  useEffect(() => {
    return () => clearHideTimeout();
  }, [clearHideTimeout]);

  const handleHoverStart = useCallback(
    (event: React.MouseEvent) => {
      if (!usesHoverInteraction) {
        return;
      }

      openPopover();

      startAudioIfNeeded(event);
    },
    [usesHoverInteraction, openPopover, startAudioIfNeeded],
  );

  const handleHoverEnd = useCallback(() => {
    if (!usesHoverInteraction) {
      return;
    }

    clearHideTimeout();
    hideTimeoutRef.current = setTimeout(() => {
      closePopover();
    }, POPUP_HIDE_DELAY_MS);
  }, [usesHoverInteraction, clearHideTimeout, closePopover]);

  // Position the popover manually so it stays within the viewport when automatic
  // repositioning is disabled.
  const getContentLocation = useCallback(
    ({ childRect, popoverRect, parentRect }: PopoverState): ContentLocation => {
      const viewportHeight =
        typeof window !== 'undefined' ? window.innerHeight : parentRect.bottom - parentRect.top;
      const viewportWidth =
        typeof window !== 'undefined' ? window.innerWidth : parentRect.right - parentRect.left;

      const preferredTop = childRect.top - popoverRect.height;
      const fallbackTop = childRect.bottom;

      let top = preferredTop;
      if (preferredTop < 0) {
        top = fallbackTop;
      }

      const maxTop = viewportHeight - popoverRect.height;
      top = Math.min(Math.max(top, 0), maxTop);

      const preferredLeft = childRect.left + childRect.width / 2 - popoverRect.width / 2;
      const maxLeft = viewportWidth - popoverRect.width;
      const left = Math.min(Math.max(preferredLeft, 0), maxLeft);

      return {
        top: top - parentRect.top,
        left: left - parentRect.left,
      };
    },
    [],
  );

  const handleAnchorClick = useCallback(
    (event: React.MouseEvent) => {
      // Prevent click from bubbling up to enclosing form elements (MER-1503).
      event.preventDefault();
      event.stopPropagation();

      if (usesHoverInteraction) {
        toggleAudioPlayback(event);
        return;
      }

      if (usesTapInteraction) {
        if (!isPopoverOpen) {
          openPopover();
          startAudioIfNeeded(event);
        }
        return;
      }

      if (popup.trigger !== 'hover') {
        if (isPopoverOpen) {
          closePopover();
        } else {
          openPopover();
          startAudioIfNeeded(event);
        }
        return;
      }
    },
    [
      usesHoverInteraction,
      usesTapInteraction,
      popup.trigger,
      isPopoverOpen,
      openPopover,
      closePopover,
      startAudioIfNeeded,
      toggleAudioPlayback,
    ],
  );

  const handleKeyDown = useCallback(
    (event: React.KeyboardEvent) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();

        if (usesHoverInteraction || usesTapInteraction) {
          if (!isPopoverOpen) {
            openPopover();
            startAudioIfNeeded(event);
          } else if (!usesHoverInteraction) {
            closePopover();
          }
          return;
        }

        if (popup.trigger !== 'hover') {
          if (isPopoverOpen) {
            closePopover();
          } else {
            openPopover();
            startAudioIfNeeded(event);
          }
        }
      }

      if (event.key === 'Escape') {
        closePopover();
      }
    },
    [
      usesHoverInteraction,
      usesTapInteraction,
      popup.trigger,
      isPopoverOpen,
      openPopover,
      closePopover,
      startAudioIfNeeded,
    ],
  );

  const showCloseButton = !usesHoverInteraction;
  const containerRole = showCloseButton ? 'dialog' : 'tooltip';
  const anchorAriaProps: Record<string, string | undefined> = showCloseButton
    ? { 'aria-controls': isPopoverOpen ? popoverId : undefined }
    : { 'aria-describedby': isPopoverOpen ? popoverId : undefined };
  const ariaHasPopup = showCloseButton ? 'dialog' : 'true';
  const labelledBy = headingId;

  const resolveParentElement = () => {
    const anchor = anchorRef.current;
    const doc = anchor?.ownerDocument;

    if (
      !scrollContainer ||
      scrollContainer === doc?.body ||
      scrollContainer === doc?.documentElement
    ) {
      return undefined;
    }

    return scrollContainer;
  };

  const resolveBoundaryElement = () => {
    const anchor = anchorRef.current;
    const doc = anchor?.ownerDocument;

    if (
      scrollContainer &&
      scrollContainer !== doc?.body &&
      scrollContainer !== doc?.documentElement
    ) {
      return scrollContainer;
    }

    return doc?.documentElement ?? undefined;
  };

  return (
    <Popover
      isOpen={isPopoverOpen}
      onClickOutside={closePopover}
      positions={['top', 'bottom']}
      align="center"
      reposition={false}
      parentElement={resolveParentElement()}
      boundaryElement={resolveBoundaryElement()}
      contentLocation={getContentLocation}
      containerClassName="z-50 react-tiny-popover structured-content pointer-events-none max-w-[320px]"
      content={({ position, childRect, popoverRect }) => (
        <ArrowContainer
          position={position}
          childRect={childRect}
          popoverRect={popoverRect}
          arrowSize={POPUP_ARROW_SIZE}
          arrowColor="currentColor"
          arrowClassName="text-Surface-surface-background z-10 translate-y-[-1px]"
        >
          <div
            id={popoverId}
            role={containerRole}
            aria-modal={showCloseButton ? 'true' : undefined}
            aria-labelledby={labelledBy}
            onMouseOver={handleHoverStart}
            onMouseLeave={handleHoverEnd}
            className="popup-content relative flex flex-col gap-3 text-sm leading-6 font-normal tracking-normal text-Text-text-high bg-Surface-surface-background border-[0.5px] border-Border-border-default p-4 rounded-md shadow-lg pointer-events-auto text-left"
          >
            {showCloseButton && (
              <button
                type="button"
                aria-label="Close key notion popup"
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                  closePopover();
                }}
                className="absolute top-0 right-0 inline-flex h-10 w-10 items-center justify-center rounded-full text-Text-text-high hover:opacity-80 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-delivery-primary"
              >
                <i className="fa-solid fa-xmark" />
              </button>
            )}
            {anchorLabel && (
              <div id={headingId} className="text-sm font-bold leading-4">
                {anchorLabel}
              </div>
            )}
            {isEmptyContent(popup.content) ? (
              <i className="fa-solid fa-volume-high" />
            ) : (
              <div className="pointer-events-auto">{popupContent}</div>
            )}
          </div>
        </ArrowContainer>
      )}
    >
      <span
        ref={(node) => {
          anchorRef.current = node;
        }}
        className="inline-flex items-center gap-1 italic font-semibold cursor-pointer text-Text-text-link hover:text-delivery-primary-hover dark:hover:text-delivery-primary-dark-hover underline decoration-dotted underline-offset-2"
        onMouseEnter={handleHoverStart}
        onMouseLeave={handleHoverEnd}
        onClick={handleAnchorClick}
        onKeyDown={handleKeyDown}
        role="button"
        tabIndex={0}
        aria-haspopup={ariaHasPopup}
        aria-expanded={isPopoverOpen}
        {...anchorAriaProps}
      >
        {hasAudio && (
          <>
            <i className={`fa-solid ${isPlaying ? 'fa-circle-pause' : 'fa-volume-high'} mx-1`} />
            {audioPlayer}
          </>
        )}
        {children}
      </span>
    </Popover>
  );
};
