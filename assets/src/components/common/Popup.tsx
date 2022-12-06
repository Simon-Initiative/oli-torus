import React, { useCallback } from 'react';
import { OverlayTriggerType } from 'react-bootstrap/esm/OverlayTrigger';
import { Popup as PopupModel } from 'data/content/model/elements/types';
import { OverlayTrigger, Popover } from 'react-bootstrap';
import { useAudio } from '../hooks/useAudio';
import { isEmptyContent } from '../../data/content/utils';

interface Props {
  children: React.ReactNode;
  popupContent: React.ReactNode;
  popup: PopupModel;
}
export const Popup: React.FC<Props> = ({ children, popupContent, popup }) => {
  const trigger: OverlayTriggerType[] = popup.trigger === 'hover' ? ['hover', 'focus'] : ['focus'];
  const { audioPlayer, playAudio, isPlaying } = useAudio(popup.audioSrc);

  const onToggle = useCallback(
    (isOpen: boolean) => {
      if (isOpen) {
        playAudio();
      } else {
        if (isPlaying) playAudio();
      }
    },
    [isPlaying, playAudio],
  );

  // This fixes https://eliterate.atlassian.net/browse/MER-1503
  const preventDefault = useCallback((e: React.MouseEvent) => e.preventDefault(), []);

  const overlayContent = (
    <Popover id={popup.id}>
      <Popover.Content className="popup__content">
        {isEmptyContent(popup.content) ? <i className="material-icons">volume_up</i> : popupContent}
      </Popover.Content>
    </Popover>
  );

  return (
    <OverlayTrigger trigger={trigger} placement="top" overlay={overlayContent} onToggle={onToggle}>
      <span
        tabIndex={0}
        onClick={preventDefault}
        role="button"
        className={`popup__anchorText${trigger.includes('hover') ? '' : ' popup__click'}`}
      >
        {children}
        {audioPlayer}
      </span>
    </OverlayTrigger>
  );
};
