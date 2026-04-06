import React, { useCallback, useMemo, useState } from 'react';
import { Button, Modal as RBModal, Table } from 'react-bootstrap';
import { useSelector } from 'react-redux';
import { WidgetProps } from '@rjsf/core';
import { MIMETYPE_FILTERS } from '../../../../../components/media/manager/MediaManager';
import { iso639_language_codes } from '../../../../../utils/language-codes-iso639';
import { selectProjectSlug } from '../../../store/app/slice';
import { MediaPickerModal } from '../../Modal/MediaPickerModal';

type SubtitleRow = {
  label?: string;
  language_code?: string;
  src?: string;
  default?: boolean;
};

const normalizeSubtitles = (value: any): SubtitleRow[] => {
  if (!value) return [];

  const asArray = Array.isArray(value) ? value : [value];

  return asArray
    .filter((s) => s && (s.src || s.language || s.language_code || s.label))
    .map((s) => {
      const src = s.src;
      const language_code = s.language_code || s.language || 'en';
      const label = s.label || s.language || s.language_code || 'Subtitles';
      const isDefault = !!s.default;
      return { src, language_code, label, default: isDefault };
    });
};

export const JanusSubtitlesManager: React.FC<WidgetProps> = (props) => {
  const { id, label, value, onChange } = props;
  const [modalOpen, setModalOpen] = useState(false);
  const [rows, setRows] = useState<SubtitleRow[]>(() => normalizeSubtitles(value));
  const [pickerOpen, setPickerOpen] = useState(false);
  const [pickerRowIndex, setPickerRowIndex] = useState<number | null>(null);
  const [isNewRow, setIsNewRow] = useState(false);
  const projectSlug: string = useSelector(selectProjectSlug);

  const trackCount = useMemo(() => normalizeSubtitles(value).length, [value]);

  const openModal = useCallback(() => {
    setRows(normalizeSubtitles(value));
    setModalOpen(true);
  }, [value]);

  const closeModal = useCallback(() => {
    setModalOpen(false);
  }, []);

  const updateRow = (index: number, patch: Partial<SubtitleRow>) => {
    setRows((prev) => {
      const next = [...prev];
      next[index] = { ...next[index], ...patch };
      return next;
    });
  };

  const onAddRow = useCallback(() => {
    // Start picker in "new row" mode; a row will be added once a URL is chosen.
    setIsNewRow(true);
    setPickerRowIndex(null);
    setPickerOpen(true);
  }, []);

  const onRemoveRow = useCallback((index: number) => {
    setRows((prev) => prev.filter((_, i) => i !== index));
  }, []);

  const onSetDefault = useCallback((index: number) => {
    setRows((prev) =>
      prev.map((row, i) => ({
        ...row,
        default: i === index,
      })),
    );
  }, []);

  const onSave = useCallback(() => {
    const cleaned = rows.filter((r) => r.src);
    onChange(cleaned.length > 0 ? cleaned : []);
    setModalOpen(false);
  }, [rows, onChange]);

  const openPickerForRow = (index: number) => {
    setIsNewRow(false);
    setPickerRowIndex(index);
    setPickerOpen(true);
  };

  const closePicker = () => {
    setPickerOpen(false);
    setPickerRowIndex(null);
  };

  const onUrlChanged = (url: string) => {
    if (isNewRow) {
      // Create a new subtitle row with sensible defaults when adding.
      setRows((prev) => [
        ...prev,
        {
          label: 'English Subtitles',
          language_code: 'en',
          src: url,
          default: prev.length === 0,
        },
      ]);
      return;
    }

    if (pickerRowIndex == null) return;
    updateRow(pickerRowIndex, { src: url });
  };

  const subtitleSummary =
    trackCount === 0
      ? 'No subtitles configured'
      : `${trackCount} subtitle${trackCount > 1 ? 's' : ''} configured`;

  return (
    <div id={id}>
      <label className="form-label mb-0">{label}</label>
      <div className="text-muted mb-1" style={{ fontSize: '0.85rem' }}>
        {subtitleSummary}
      </div>
      <div className="mb-2">
        <Button
          onClick={openModal}
          type="button"
          variant="secondary"
          size="sm"
          aria-label="Select Caption File"
        >
          <i className="fa-solid fa-closed-captioning" />
        </Button>
        <a
          href="#"
          style={{ marginLeft: '5px', textDecoration: 'underline' }}
          onClick={(e) => {
            e.preventDefault();
            openModal();
          }}
        >
          Upload or Link Captions
        </a>
      </div>

      <RBModal show={modalOpen} onHide={closeModal} size="lg">
        <RBModal.Header closeButton>
          <RBModal.Title>Subtitles</RBModal.Title>
        </RBModal.Header>
        <RBModal.Body>
          <p className="mb-2">
            Provide subtitles for the video. These will be displayed to viewers who choose to turn
            them on and can be supplied in multiple languages. You must provide a file formatted as
            a{' '}
            <a
              href="https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API"
              target="_blank"
              rel="noreferrer"
            >
              Web Video Text Tracks
            </a>{' '}
            (WebVTT) file.
          </p>
          <Table striped bordered size="sm" className="mb-3">
            <thead>
              <tr>
                <th>Label</th>
                <th>Language</th>
                <th>URL</th>
                <th>Default</th>
                <th>Remove</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row, index) => (
                <tr key={index}>
                  <td style={{ width: '230px' }}>
                    <input
                      type="text"
                      className="form-control"
                      value={row.label || ''}
                      onChange={(e) => updateRow(index, { label: e.target.value })}
                    />
                  </td>
                  <td>
                    <select
                      className="form-control"
                      value={row.language_code || ''}
                      onChange={(e) =>
                        updateRow(index, { language_code: e.target.value || undefined })
                      }
                    >
                      <option value="">None Selected</option>
                      {iso639_language_codes.map(
                        ({ code, name }: { code: string; name: string }) => (
                          <option key={code} value={code}>
                            {name} [{code}]
                          </option>
                        ),
                      )}
                    </select>
                  </td>
                  <td>
                    <div className="d-flex align-items-center">
                      <div className="truncate-left flex-grow-1 mr-2">
                        {row.src || <span className="text-muted">No Caption File</span>}
                      </div>
                      <Button
                        variant="secondary"
                        size="sm"
                        type="button"
                        onClick={() => openPickerForRow(index)}
                        aria-label="Select Caption File"
                      >
                        <i className="fa-solid fa-closed-captioning" />
                      </Button>
                    </div>
                  </td>
                  <td className="text-center">
                    <input
                      type="radio"
                      name={`${id}-default-subtitle`}
                      checked={!!row.default}
                      onChange={() => onSetDefault(index)}
                    />
                  </td>
                  <td className="text-center">
                    <Button
                      variant="link"
                      type="button"
                      onClick={() => onRemoveRow(index)}
                      aria-label="Remove subtitle"
                    >
                      <i className="fas fa-trash" />
                    </Button>
                  </td>
                </tr>
              ))}
              <tr>
                <td colSpan={5}>
                  <Button variant="success" type="button" onClick={onAddRow}>
                    Add New
                  </Button>
                </td>
              </tr>
            </tbody>
          </Table>
        </RBModal.Body>
        <RBModal.Footer>
          <Button variant="secondary" type="button" onClick={closeModal}>
            Cancel
          </Button>
          <Button variant="primary" type="button" onClick={onSave}>
            Save
          </Button>
        </RBModal.Footer>
      </RBModal>

      {pickerOpen && (isNewRow || pickerRowIndex != null) && (
        <MediaPickerModal
          initialSelection={
            isNewRow || pickerRowIndex == null ? '' : rows[pickerRowIndex]?.src || ''
          }
          onUrlChanged={onUrlChanged}
          projectSlug={projectSlug}
          onOK={closePicker}
          onCancel={closePicker}
          mimeFilter={MIMETYPE_FILTERS.CAPTIONS}
          title="Select Caption File"
        />
      )}
    </div>
  );
};
