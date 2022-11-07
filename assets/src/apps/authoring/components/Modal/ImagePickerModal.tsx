import { Button, Modal } from 'react-bootstrap';
import React, { useCallback, useState } from 'react';
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
}

/**
 * Media manager component wrapped in a react-bootstrap modal, initially for advanced authoring environment usage.
 **/

export const ImagePickerModal: React.FC<Props> = ({
  projectSlug,
  initialSelection,
  onCancel,
  onOK,
  onUrlChanged,
}) => {
  const onMediaSelected = useCallback((items: MediaItem[]) => {
    if (items.length > 0) {
      onUrlChanged(items[0].url);
    }
  }, []);

  return (
    <Modal show={true} size={'xl'} onHide={onCancel}>
      <Modal.Header closeButton={true}>
        <h3 className="modal-title">Select Image</h3>
      </Modal.Header>
      <Modal.Body>
        <UrlOrUpload
          onUrlChange={onUrlChanged}
          onMediaSelectionChange={onMediaSelected}
          projectSlug={projectSlug}
          mimeFilter={MIMETYPE_FILTERS.IMAGE}
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
