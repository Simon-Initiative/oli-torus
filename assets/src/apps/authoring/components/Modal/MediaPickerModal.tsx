import React, { useCallback } from 'react';
import { Button, Modal } from 'react-bootstrap';
import { UrlOrUpload } from '../../../../components/media/UrlOrUpload';
import {
  MIMETYPE_FILTERS,
  SELECTION_TYPES,
} from '../../../../components/media/manager/MediaManager';
import { MediaItem } from '../../../../types/media';

interface Props {
  initialSelection: string;
  onCancel: () => void;
  onOK: () => void;
  projectSlug: string;
  onUrlChanged: (url: string) => void;
  mimeFilter?: string[] | undefined;
  title?: string;
}

/**
 * Media manager component wrapped in a react-bootstrap modal, initially for advanced authoring environment usage.
 **/

export const MediaPickerModal: React.FC<Props> = ({
  projectSlug,
  initialSelection,
  onCancel,
  onOK,
  onUrlChanged,
  mimeFilter,
  title,
}) => {
  const onMediaSelected = useCallback(
    (items: MediaItem[]) => {
      if (items.length > 0) {
        onUrlChanged(items[0].url);
      }
    },
    [onUrlChanged],
  );

  return (
    <Modal show={true} size={'xl'} onHide={onCancel}>
      <Modal.Header closeButton={true}>
        <h3 className="modal-title">{title}</h3>
      </Modal.Header>
      <Modal.Body>
        <UrlOrUpload
          onUrlChange={onUrlChanged}
          onMediaSelectionChange={onMediaSelected}
          projectSlug={projectSlug}
          mimeFilter={mimeFilter}
          selectionType={SELECTION_TYPES.SINGLE}
          initialSelectionPaths={initialSelection ? [initialSelection] : []}
        />
      </Modal.Body>
      <Modal.Footer>
        <Button type="button" variant="secondary" onClick={onCancel}>
          Cancel
        </Button>
        <Button type="button" variant="primary" onClick={onOK}>
          OK
        </Button>
      </Modal.Footer>
    </Modal>
  );
};

MediaPickerModal.defaultProps = {
  mimeFilter: MIMETYPE_FILTERS.IMAGE,
  title: 'Select Image',
};
