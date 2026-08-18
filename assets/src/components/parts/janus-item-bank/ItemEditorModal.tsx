import React, { useCallback, useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import { MediaPickerModal } from '../../../apps/authoring/components/Modal/MediaPickerModal';
import { htmlToPlainText, normalizeRichLabelForStorage } from '../../../utils/richOptionLabel';
import { RichLabelField } from '../common/RichLabelField';
import './ItemBankAuthorModal.scss';
import { genId } from './grouping-util';
import { GroupingItem, GroupingItemType } from './schema';

export interface ItemEditorModalProps {
  show: boolean;
  initialItem: GroupingItem | null;
  existingLabels: string[];
  projectSlug: string;
  onSave: (item: GroupingItem) => void;
  onCancel: () => void;
}

const basenameFromUrl = (url: string): string => {
  const parts = url.split('/');
  const last = parts[parts.length - 1] || 'Image';
  return last.split('?')[0] || 'Image';
};

const ItemEditorModal: React.FC<ItemEditorModalProps> = ({
  show,
  initialItem,
  existingLabels,
  projectSlug,
  onSave,
  onCancel,
}) => {
  const [type, setType] = useState<GroupingItemType>('text');
  const [label, setLabel] = useState('');
  const [text, setText] = useState('');
  const [imageSrc, setImageSrc] = useState('');
  const [alt, setAlt] = useState('');
  const [error, setError] = useState('');
  const [imagePickerOpen, setImagePickerOpen] = useState(false);
  const [pendingImageUrl, setPendingImageUrl] = useState('');

  const isEdit = !!initialItem;

  useEffect(() => {
    if (show) {
      setType(initialItem?.type || 'text');
      setLabel(initialItem?.label || '');
      setText(initialItem?.text || '');
      setImageSrc(initialItem?.imageSrc || '');
      setAlt(initialItem?.alt || '');
      setError('');
      setImagePickerOpen(false);
      setPendingImageUrl('');
    }
  }, [show, initialItem]);

  const handleSave = useCallback(() => {
    const trimmedLabel = label.trim();
    const normalizedText = normalizeRichLabelForStorage(text);
    const trimmedAlt = alt.trim();

    if (!trimmedLabel) {
      setError('Short label is required.');
      return;
    }

    if (existingLabels.includes(trimmedLabel.toLowerCase())) {
      setError('Short label must be unique.');
      return;
    }

    if (type === 'text') {
      if (!htmlToPlainText(normalizedText)) {
        setError('Text is required.');
        return;
      }
    } else if (!imageSrc.trim()) {
      setError('Please choose an image.');
      return;
    }

    const item: GroupingItem = {
      id: initialItem?.id ?? genId('item'),
      type,
      label: trimmedLabel,
      ...(type === 'text'
        ? { text: normalizedText }
        : {
            imageSrc: imageSrc.trim(),
            alt: trimmedAlt,
            text: normalizedText,
          }),
    };

    onSave(item);
  }, [alt, existingLabels, imageSrc, initialItem?.id, label, onSave, text, type]);

  const handleImagePickerOk = useCallback(() => {
    const url = pendingImageUrl.trim();
    if (url) {
      setImageSrc(url);
      if (!label.trim()) {
        setLabel(basenameFromUrl(url));
      }
    }
    setImagePickerOpen(false);
    setPendingImageUrl('');
  }, [label, pendingImageUrl]);

  return (
    <>
      <AdvancedAuthoringModal show={show} onHide={onCancel} size="lg">
        <Modal.Header closeButton>
          <Modal.Title>{isEdit ? 'Edit Item' : 'Add Item'}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="item-editor-modal">
            <div className="iem-field">
              <label className="iem-label">Type</label>
              <div className="iem-type-toggle" role="group" aria-label="Item type">
                <button
                  type="button"
                  className={`iem-type-btn${type === 'text' ? ' active' : ''}`}
                  onClick={() => {
                    setType('text');
                    setError('');
                  }}
                >
                  Text
                </button>
                <button
                  type="button"
                  className={`iem-type-btn${type === 'image' ? ' active' : ''}`}
                  onClick={() => {
                    setType('image');
                    setError('');
                  }}
                >
                  Image
                </button>
              </div>
            </div>

            <div className="iem-field">
              <label className="iem-label" htmlFor="iem-short-label">
                Short label
              </label>
              <span className="iem-hint">Unique identifier used in adaptivity variables</span>
              <input
                id="iem-short-label"
                type="text"
                className="form-control"
                value={label}
                onChange={(e) => {
                  setLabel(e.target.value);
                  setError('');
                }}
                placeholder="e.g. item-one"
              />
            </div>

            {type === 'text' ? (
              <div className="iem-field">
                <label className="iem-label" htmlFor="iem-text">
                  Text
                </label>
                <span className="iem-hint">Content shown on the item card</span>
                <RichLabelField
                  id="iem-text"
                  inline
                  value={text}
                  onChange={(next) => {
                    setText(next);
                    setError('');
                  }}
                />
              </div>
            ) : (
              <>
                <div className="iem-field">
                  <label className="iem-label">Image</label>
                  <div className="iem-image-row">
                    {imageSrc ? (
                      <img
                        className="iem-image-preview"
                        src={imageSrc}
                        alt={alt.trim() || htmlToPlainText(text) || label.trim()}
                      />
                    ) : (
                      <div className="iem-image-placeholder">No image selected</div>
                    )}
                    <button
                      type="button"
                      className="btn btn-outline-primary btn-sm"
                      onClick={() => {
                        setPendingImageUrl(imageSrc);
                        setImagePickerOpen(true);
                      }}
                    >
                      Choose image
                    </button>
                  </div>
                </div>
                <div className="iem-field">
                  <label className="iem-label" htmlFor="iem-image-text">
                    Text
                  </label>
                  <span className="iem-hint">
                    Optional caption shown above the image on the item card
                  </span>
                  <RichLabelField
                    id="iem-image-text"
                    inline
                    value={text}
                    onChange={(next) => {
                      setText(next);
                      setError('');
                    }}
                  />
                </div>
                <div className="iem-field">
                  <label className="iem-label" htmlFor="iem-alt">
                    Alt text
                  </label>
                  <span className="iem-hint">Accessibility description for the image</span>
                  <input
                    id="iem-alt"
                    type="text"
                    className="form-control"
                    value={alt}
                    onChange={(e) => setAlt(e.target.value)}
                    placeholder="Describe the image…"
                  />
                </div>
              </>
            )}

            {error && (
              <div className="iem-error" role="alert">
                {error}
              </div>
            )}
          </div>
        </Modal.Body>
        <Modal.Footer>
          <button type="button" className="btn btn-secondary" onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className="btn btn-primary" onClick={handleSave}>
            Save
          </button>
        </Modal.Footer>
      </AdvancedAuthoringModal>

      {imagePickerOpen && (
        <MediaPickerModal
          projectSlug={projectSlug}
          initialSelection={pendingImageUrl}
          onUrlChanged={setPendingImageUrl}
          onOK={handleImagePickerOk}
          onCancel={() => {
            setImagePickerOpen(false);
            setPendingImageUrl('');
          }}
        />
      )}
    </>
  );
};

export default ItemEditorModal;
