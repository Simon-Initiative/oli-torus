import React, { useCallback, useEffect, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import { MediaPickerModal } from '../../../apps/authoring/components/Modal/MediaPickerModal';
import { htmlToPlainText, normalizeRichLabelForStorage } from '../../../utils/richOptionLabel';
import { RichLabelField } from '../common/RichLabelField';
import './MatchingAuthorModal.scss';
import { genId } from './matching-util';
import { MatchingItem, MatchingItemType } from './schema';

export interface MatchingItemEditorModalProps {
  show: boolean;
  initialItem: MatchingItem | null;
  existingLabels: string[];
  projectSlug: string;
  onSave: (item: MatchingItem) => void;
  onCancel: () => void;
}

const basenameFromUrl = (url: string): string => {
  const parts = url.split('/');
  const last = parts[parts.length - 1] || 'Image';
  return last.split('?')[0] || 'Image';
};

const MatchingItemEditorModal: React.FC<MatchingItemEditorModalProps> = ({
  show,
  initialItem,
  existingLabels,
  projectSlug,
  onSave,
  onCancel,
}) => {
  const [type, setType] = useState<MatchingItemType>('text');
  const [label, setLabel] = useState('');
  const [text, setText] = useState('');
  const [imageSrc, setImageSrc] = useState('');
  const [alt, setAlt] = useState('');
  const [maxLinks, setMaxLinks] = useState(1);
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
      setMaxLinks(initialItem?.maxLinks || 1);
      setError('');
      setImagePickerOpen(false);
      setPendingImageUrl('');
    }
  }, [show, initialItem]);

  const handleSave = useCallback(() => {
    const trimmedLabel = label.trim();
    const normalizedText = normalizeRichLabelForStorage(text);
    const trimmedAlt = alt.trim();
    const links = Math.max(1, Math.min(10, Number(maxLinks) || 1));

    if (!trimmedLabel) {
      setError('Short label is required.');
      return;
    }

    if (existingLabels.includes(trimmedLabel.toLowerCase())) {
      setError('Short label must be unique across both columns.');
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

    const item: MatchingItem = {
      id: initialItem?.id ?? genId('item'),
      type,
      label: trimmedLabel,
      maxLinks: links,
      ...(type === 'text'
        ? { text: normalizedText }
        : {
            imageSrc: imageSrc.trim(),
            alt: trimmedAlt,
            text: normalizedText,
          }),
    };

    onSave(item);
  }, [alt, existingLabels, imageSrc, initialItem?.id, label, maxLinks, onSave, text, type]);

  const handleImagePickerOk = useCallback(() => {
    const url = pendingImageUrl.trim();
    if (url) {
      setImageSrc(url);
      if (!label.trim()) {
        setLabel(basenameFromUrl(url));
      }
      if (!alt.trim()) {
        setAlt(basenameFromUrl(url));
      }
    }
    setImagePickerOpen(false);
    setPendingImageUrl('');
  }, [alt, label, pendingImageUrl]);

  return (
    <>
      <AdvancedAuthoringModal show={show} onHide={onCancel} size="lg">
        <Modal.Header closeButton>
          <Modal.Title>{isEdit ? 'Edit Item' : 'Add Item'}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <div className="matching-item-editor">
            <div className="mie-field">
              <label className="mie-label">Type</label>
              <div className="mie-type-toggle" role="group" aria-label="Item type">
                <button
                  type="button"
                  className={`mie-type-btn${type === 'text' ? ' active' : ''}`}
                  disabled={isEdit}
                  onClick={() => {
                    if (isEdit) {
                      return;
                    }
                    setType('text');
                    setError('');
                  }}
                >
                  Text
                </button>
                <button
                  type="button"
                  className={`mie-type-btn${type === 'image' ? ' active' : ''}`}
                  disabled={isEdit}
                  onClick={() => {
                    if (isEdit) {
                      return;
                    }
                    setType('image');
                    setError('');
                  }}
                >
                  Image
                </button>
              </div>
              {isEdit && (
                <span className="mie-hint">
                  Content type can’t be changed after the item is created
                </span>
              )}
            </div>

            <div className="mie-field">
              <label className="mie-label" htmlFor="mie-short-label">
                Short label
              </label>
              <span className="mie-hint">Unique identifier used in adaptivity variables</span>
              <input
                id="mie-short-label"
                type="text"
                className="form-control"
                value={label}
                onChange={(e) => {
                  setLabel(e.target.value);
                  setError('');
                }}
                placeholder="e.g. Term A"
              />
            </div>

            {type === 'text' ? (
              <div className="mie-field">
                <label className="mie-label" htmlFor="mie-text">
                  Text
                </label>
                <span className="mie-hint">Content shown on the item card</span>
                <RichLabelField
                  id="mie-text"
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
                <div className="mie-field">
                  <label className="mie-label">Image</label>
                  <div className="mie-image-row">
                    {imageSrc ? (
                      <img
                        className="mie-image-preview"
                        src={imageSrc}
                        alt={alt || htmlToPlainText(text) || label}
                      />
                    ) : (
                      <div className="mie-image-placeholder">No image selected</div>
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
                <div className="mie-field">
                  <label className="mie-label" htmlFor="mie-image-text">
                    Caption
                  </label>
                  <span className="mie-hint">
                    Optional caption shown above the image on the item card
                  </span>
                  <RichLabelField
                    id="mie-image-text"
                    inline
                    value={text}
                    onChange={(next) => {
                      setText(next);
                      setError('');
                    }}
                  />
                </div>
                <div className="mie-field">
                  <label className="mie-label" htmlFor="mie-alt">
                    Alt text
                  </label>
                  <span className="mie-hint">Accessibility description for the image</span>
                  <input
                    id="mie-alt"
                    type="text"
                    className="form-control"
                    value={alt}
                    onChange={(e) => setAlt(e.target.value)}
                    placeholder="Describe the image…"
                  />
                </div>
              </>
            )}

            <div className="mie-field">
              <label className="mie-label" htmlFor="mie-max-links">
                Number of allowed links
              </label>
              <span className="mie-hint">Maximum matches this item can participate in (1–10)</span>
              <input
                id="mie-max-links"
                type="number"
                className="form-control"
                min={1}
                max={10}
                value={maxLinks}
                onChange={(e) => setMaxLinks(Number(e.target.value) || 1)}
              />
            </div>

            {error && (
              <div className="mie-error" role="alert">
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

export default MatchingItemEditorModal;
