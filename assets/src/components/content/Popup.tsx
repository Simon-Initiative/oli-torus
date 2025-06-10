import React, { useCallback, useRef, useState } from 'react';
import { ArrowContainer, Popover } from 'react-tiny-popover';
import { Popup as PopupModel } from 'data/content/model/elements/types';
import { isEmptyContent } from '../../data/content/utils';
import { useAudio } from '../hooks/useAudio';
import { positionRect } from '../../data/content/utils';

interface Props {
  children: React.ReactNode;
  popupContent: React.ReactNode;
  popup: PopupModel;
}
export const Popup: React.FC<Props> = ({ children, popupContent, popup }) => {
  const { audioPlayer, playAudio, isPlaying } = useAudio(popup.audioSrc);
  const hasAudio = !!popup.audioSrc;
  const hideInterval = useRef<NodeJS.Timeout | null>(null);

  const [isPopoverOpen, setIsPopoverOpen] = useState<boolean>(false);

  const pauseAudio = useCallback(() => {
    // if the audio is already playing, pause it
    if (isPlaying) playAudio();
  }, [isPlaying, playAudio]);

  const onHover = useCallback(
    (e: React.MouseEvent) => {
      if (popup.trigger === 'hover') {
        setIsPopoverOpen(true);
        playAudio();
        hideInterval.current && clearTimeout(hideInterval.current);
      }
    },
    [popup, setIsPopoverOpen, playAudio],
  );
  const onBlur = useCallback(
    (e: React.MouseEvent) => {
      if (popup.trigger === 'hover') {
        pauseAudio();
        hideInterval.current = setTimeout(() => setIsPopoverOpen(false), 1000);
        // Instead of hiding right away, let's wait a bit to see if the user is moving the mouse to the popup
      }
    },
    [popup, setIsPopoverOpen, pauseAudio],
  );
  const onClick = useCallback(
    (e: React.MouseEvent) => {
      if (hasAudio) {
        // Click behaves differently depending if the popup has audio or not to allow better control of audio playback.
        // If the popup is hover triggered and has audio, then a click should control the audio.
        // This allows a user to control the audio playback while still being able to see popup content
        isPlaying ? pauseAudio() : playAudio();

        if (popup.trigger !== 'hover' && hasAudio && !isPopoverOpen) {
          // If the popup is triggered via click and has audio, then a click should open the popup.
          // To dismiss the popup, the user must click outside the popup
          setIsPopoverOpen(true);
        }
      } else {
        // If the popup has no audio, then a click should simply toggle the popup
        setIsPopoverOpen(!isPopoverOpen);
      }

      // prevent click from submitting a response when the popup is clicked inside a choice
      // https://eliterate.atlassian.net/browse/MER-1503
      e.preventDefault();
    },
    [popup.trigger, isPlaying, isPopoverOpen, hasAudio, setIsPopoverOpen, playAudio, pauseAudio],
  );

  return (
    <Popover
      isOpen={isPopoverOpen}
      onClickOutside={() => (setIsPopoverOpen(false), pauseAudio())}
      positions={['top', 'bottom', 'left', 'right']}
      reposition={false}
      content={({ position, childRect, popoverRect }) => (
        <ArrowContainer
          position={position}
          childRect={childRect}
          popoverRect={popoverRect}
          arrowSize={10}
          arrowColor="currentColor"
          arrowClassName="text-delivery-tooltip-bg dark:text-delivery-tooltip-bg-dark z-10 translate-y-[-1px]"
        >
          <div
            onMouseOver={onHover}
            onMouseLeave={onBlur}
            className="popup-content text-sm text-delivery-tooltip-content dark:text-delivery-tooltip-content-dark bg-delivery-tooltip-bg dark:bg-delivery-tooltip-bg-dark p-4 drop-shadow rounded"
          >
            {isEmptyContent(popup.content) ? (
              <i className="fa-solid fa-volume-high" />
            ) : (
              <span className="pointer-events-auto">{popupContent}</span>
            )}
          </div>
        </ArrowContainer>
      )}
      containerClassName="z-50 react-tiny-popover structured-content pointer-events-none max-w-[300px]"
    >
      <span
        className="italic font-bold cursor-pointer text-delivery-primary dark:text-delivery-primary-dark hover:text-delivery-primary-hover dark:hover:text-delivery-primary-dark-hover"
        onMouseEnter={onHover}
        onMouseLeave={onBlur}
        onClick={onClick}
      >
        {hasAudio && (
          <>
            {isPlaying ? (
              <i className="fa-solid fa-circle-pause mx-1"></i>
            ) : (
              <i className="fa-solid fa-volume-high mx-1"></i>
            )}
            {audioPlayer}
          </>
        )}
        {children}
      </span>
    </Popover>
  );
};
