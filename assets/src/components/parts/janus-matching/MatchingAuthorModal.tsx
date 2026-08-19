import React, { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import ConfirmDelete from '../../../apps/authoring/components/Modal/DeleteConfirmationModal';
import './MatchingAuthorModal.scss';
import MatchingItemContent from './MatchingItemContent';
import MatchingItemEditorModal from './MatchingItemEditorModal';
import MatchingLines from './MatchingLines';
import {
  DrawnLine,
  areDrawnLinesEqual,
  buildDrawnLines,
  countMatches,
  matchingThemeStyles,
  normalizeMatchingItemForSave,
  normalizeMatchingItemsForSave,
  removeItemFromMatches,
  toggleMatch,
} from './matching-util';
import { DEFAULT_MATCHING_THEME, MatchingItem, MatchingMatches, MatchingModel } from './schema';

type AuthorMode = 'manage' | 'answer';

export interface MatchingAuthorModalProps {
  show: boolean;
  model: Pick<
    MatchingModel,
    | 'column1Title'
    | 'column2Title'
    | 'column1Items'
    | 'column2Items'
    | 'correctMatches'
    | 'themeColor'
  >;
  projectSlug: string;
  onSave: (
    snapshot: Pick<
      MatchingModel,
      'column1Title' | 'column2Title' | 'column1Items' | 'column2Items' | 'correctMatches'
    >,
  ) => void;
  onCancel: () => void;
}

const MatchingAuthorModal: React.FC<MatchingAuthorModalProps> = ({
  show,
  model,
  projectSlug,
  onSave,
  onCancel,
}) => {
  const [mode, setMode] = useState<AuthorMode>('manage');
  const [column1Title, setColumn1Title] = useState('Column 1');
  const [column2Title, setColumn2Title] = useState('Column 2');
  const [column1Items, setColumn1Items] = useState<MatchingItem[]>([]);
  const [column2Items, setColumn2Items] = useState<MatchingItem[]>([]);
  const [correctMatches, setCorrectMatches] = useState<MatchingMatches>({});
  const [lines, setLines] = useState<DrawnLine[]>([]);
  const [draft, setDraft] = useState<{ x1: number; y1: number; x2: number; y2: number } | null>(
    null,
  );
  const [draggingFromId, setDraggingFromId] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<{
    col: 1 | 2;
    itemId: string;
  } | null>(null);
  const [itemEditor, setItemEditor] = useState<{
    open: boolean;
    col: 1 | 2;
    item: MatchingItem | null;
  }>({ open: false, col: 1, item: null });

  const stageRef = useRef<HTMLDivElement>(null);
  const itemRefs = useRef<Record<string, HTMLDivElement | null>>({});

  const themeColor = model.themeColor || DEFAULT_MATCHING_THEME;

  useEffect(() => {
    if (show) {
      setMode('manage');
      setColumn1Title(model.column1Title || 'Column 1');
      setColumn2Title(model.column2Title || 'Column 2');
      setColumn1Items(normalizeMatchingItemsForSave(model.column1Items || []));
      setColumn2Items(normalizeMatchingItemsForSave(model.column2Items || []));
      setCorrectMatches(model.correctMatches || {});
      setDraggingFromId(null);
      setDraft(null);
      setConfirmDelete(null);
      setItemEditor({ open: false, col: 1, item: null });
    }
  }, [show, model]);

  const redrawLines = useCallback(() => {
    if (mode !== 'answer' || !stageRef.current) {
      setLines((prev) => (prev.length === 0 ? prev : []));
      return;
    }
    const stageRect = stageRef.current.getBoundingClientRect();
    const next = buildDrawnLines(correctMatches, (itemId, side) => {
      const el = itemRefs.current[itemId];
      if (!el) {
        return null;
      }
      const rect = el.getBoundingClientRect();
      return {
        x: side === 'left' ? rect.right - stageRect.left : rect.left - stageRect.left,
        y: (rect.top + rect.bottom) / 2 - stageRect.top,
      };
    });
    setLines((prev) => (areDrawnLinesEqual(prev, next) ? prev : next));
  }, [correctMatches, mode]);

  useLayoutEffect(() => {
    redrawLines();
  }, [redrawLines, column1Items, column2Items]);

  useEffect(() => {
    window.addEventListener('resize', redrawLines);
    return () => window.removeEventListener('resize', redrawLines);
  }, [redrawLines]);

  const getStagePoint = (clientX: number, clientY: number) => {
    if (!stageRef.current) {
      return { x: 0, y: 0 };
    }
    const rect = stageRef.current.getBoundingClientRect();
    return { x: clientX - rect.left, y: clientY - rect.top };
  };

  const startDrag = (col1Id: string, clientX: number, clientY: number) => {
    const el = itemRefs.current[col1Id];
    if (!el || !stageRef.current) {
      return;
    }
    const stageRect = stageRef.current.getBoundingClientRect();
    const rect = el.getBoundingClientRect();
    const start = {
      x: rect.right - stageRect.left,
      y: (rect.top + rect.bottom) / 2 - stageRect.top,
    };
    const point = getStagePoint(clientX, clientY);
    setDraggingFromId(col1Id);
    setDraft({ x1: start.x, y1: start.y, x2: point.x, y2: point.y });
  };

  useEffect(() => {
    if (!draggingFromId) {
      return;
    }

    const onMove = (e: PointerEvent) => {
      setDraft((prev) => {
        if (!prev) {
          return prev;
        }
        const point = getStagePoint(e.clientX, e.clientY);
        return { ...prev, x2: point.x, y2: point.y };
      });
    };

    const onUp = (e: PointerEvent) => {
      const target = document.elementFromPoint(e.clientX, e.clientY) as HTMLElement | null;
      const col2Id = target?.closest?.('[data-matching-col2]')?.getAttribute('data-item-id');
      const col1Item = column1Items.find((i) => i.id === draggingFromId);
      const col2Item = column2Items.find((i) => i.id === col2Id);
      if (col1Item && col2Item) {
        setCorrectMatches((prev) => toggleMatch(prev, col1Item, col2Item));
      }
      setDraggingFromId(null);
      setDraft(null);
    };

    window.addEventListener('pointermove', onMove);
    window.addEventListener('pointerup', onUp);
    return () => {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
    };
  }, [column1Items, column2Items, draggingFromId]);

  const handleLineClick = useCallback(
    (line: DrawnLine) => {
      const col1Item = column1Items.find((i) => i.id === line.col1Id);
      const col2Item = column2Items.find((i) => i.id === line.col2Id);
      if (!col1Item || !col2Item) {
        return;
      }
      setCorrectMatches((prev) => toggleMatch(prev, col1Item, col2Item));
    },
    [column1Items, column2Items],
  );

  const allLabelsExcept = (excludeId?: string) =>
    [...column1Items, ...column2Items]
      .filter((i) => i.id !== excludeId)
      .map((i) => i.label.trim().toLowerCase());

  const handleItemSave = (item: MatchingItem) => {
    const normalized = normalizeMatchingItemForSave(item);
    const setter = itemEditor.col === 1 ? setColumn1Items : setColumn2Items;
    setter((prev) =>
      prev.some((i) => i.id === normalized.id)
        ? prev.map((i) => (i.id === normalized.id ? normalized : i))
        : [...prev, normalized],
    );
    setItemEditor({ open: false, col: 1, item: null });
  };

  const addItem = (col: 1 | 2) => {
    setItemEditor({ open: true, col, item: null });
  };

  const confirmDeleteItem = () => {
    if (!confirmDelete) {
      return;
    }
    const { col, itemId } = confirmDelete;
    const items = col === 1 ? column1Items : column2Items;
    if (items.length <= 1) {
      setConfirmDelete(null);
      return;
    }
    const setter = col === 1 ? setColumn1Items : setColumn2Items;
    setter((prev) => prev.filter((i) => i.id !== itemId));
    setCorrectMatches((prev) => removeItemFromMatches(prev, itemId));
    setConfirmDelete(null);
  };

  const handleSave = () => {
    onSave({
      column1Title: column1Title.trim() || 'Column 1',
      column2Title: column2Title.trim() || 'Column 2',
      column1Items: normalizeMatchingItemsForSave(column1Items),
      column2Items: normalizeMatchingItemsForSave(column2Items),
      correctMatches,
    });
  };

  const matchCount = countMatches(correctMatches);
  const bottomMsg =
    mode === 'manage'
      ? 'Add and configure items in both columns. Switch to Edit Correct State to draw matches.'
      : 'Drag from a Column 1 item to a Column 2 item to draw a match. Click a line (or redraw the same pair) to remove it.';

  const renderItem = (col: 1 | 2, item: MatchingItem) => {
    const isDragging = mode === 'answer' && draggingFromId === item.id;
    const classes = [
      'mam-item',
      mode === 'answer' && col === 1 ? 'is-drawable' : '',
      mode === 'answer' && col === 2 ? 'is-drop-target' : '',
      isDragging ? 'is-selected' : '',
    ]
      .filter(Boolean)
      .join(' ');

    return (
      <div
        key={item.id}
        ref={(el) => {
          itemRefs.current[item.id] = el;
        }}
        className={classes}
        data-item-id={item.id}
        {...(col === 1 && mode === 'answer' ? { 'data-matching-col1': '' } : {})}
        {...(col === 2 && mode === 'answer' ? { 'data-matching-col2': '' } : {})}
        onPointerDown={
          mode === 'answer' && col === 1
            ? (e) => {
                if (e.button !== 0) {
                  return;
                }
                e.preventDefault();
                startDrag(item.id, e.clientX, e.clientY);
              }
            : undefined
        }
      >
        <div className="mam-item-body">
          <MatchingItemContent item={item} />
        </div>
        {mode === 'manage' && (
          <div className="mam-item-actions">
            <button
              type="button"
              className="mam-iab del"
              title="Delete"
              aria-label="Delete item"
              onClick={() => setConfirmDelete({ col, itemId: item.id })}
            >
              <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true" focusable="false">
                <path
                  fill="currentColor"
                  d="M6 2h4l.5 1H14v1.5H2V3h3.5L6 2zm1 3.5V12h1.5V5.5H7zm2.5 0V12H11V5.5H9.5zM4.5 5.5V13c0 .8.7 1.5 1.5 1.5h4c.8 0 1.5-.7 1.5-1.5V5.5H4.5z"
                />
              </svg>
            </button>
            <button
              type="button"
              className="mam-iab"
              title="Edit item"
              aria-label="Edit item"
              onClick={() => setItemEditor({ open: true, col, item })}
            >
              <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true" focusable="false">
                <path
                  fill="currentColor"
                  d="M11.7 2.3a1 1 0 0 1 1.4 1.4l-8 8L3 13l1.3-2.1 7.4-8.6z"
                />
              </svg>
            </button>
          </div>
        )}
      </div>
    );
  };

  const body = (
    <div
      className={`matching-author-modal mam-mode-${mode}`}
      style={matchingThemeStyles(themeColor)}
    >
      <div className="mam-toolbar">
        <div className="mam-mode-switch" role="tablist" aria-label="Matching mode">
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'manage'}
            className={`mam-mode-option${mode === 'manage' ? ' active' : ''}`}
            onClick={() => {
              setMode('manage');
              setDraggingFromId(null);
              setDraft(null);
            }}
          >
            Edit Mode
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'answer'}
            className={`mam-mode-option${mode === 'answer' ? ' active active-answer' : ''}`}
            onClick={() => setMode('answer')}
          >
            Edit Correct State
          </button>
        </div>
        {mode === 'answer' && <span className="mam-answer-label">Draw correct matches</span>}
        <div className="mam-spacer" />
      </div>

      <div className="mam-stage" ref={stageRef}>
        {mode === 'answer' && (
          <MatchingLines
            lines={lines}
            draft={draft}
            themeColor={themeColor}
            onLineClick={handleLineClick}
          />
        )}
        <div className="mam-columns">
          <div className="mam-column">
            <div className="mam-col-header">
              <input
                className="mam-col-title-input"
                value={column1Title}
                onChange={(e) => setColumn1Title(e.target.value)}
                disabled={mode !== 'manage'}
                aria-label="Column 1 title"
              />
            </div>
            <div className="mam-items">{column1Items.map((item) => renderItem(1, item))}</div>
            {mode === 'manage' && (
              <button type="button" className="mam-add-btn" onClick={() => addItem(1)}>
                + Add Item
              </button>
            )}
          </div>

          <div className="mam-column">
            <div className="mam-col-header">
              <input
                className="mam-col-title-input"
                value={column2Title}
                onChange={(e) => setColumn2Title(e.target.value)}
                disabled={mode !== 'manage'}
                aria-label="Column 2 title"
              />
            </div>
            <div className="mam-items">{column2Items.map((item) => renderItem(2, item))}</div>
            {mode === 'manage' && (
              <button type="button" className="mam-add-btn" onClick={() => addItem(2)}>
                + Add Item
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="mam-bottombar">
        <span className="mam-bottom-hint">{bottomMsg}</span>
        <span className="mam-status-pill">
          {column1Items.length} + {column2Items.length} items
          {mode === 'answer' ? ` · ${matchCount} match${matchCount !== 1 ? 'es' : ''}` : ''}
        </span>
      </div>

      {confirmDelete && (
        <ConfirmDelete
          show={!!confirmDelete}
          elementType="item"
          elementName={`"${
            [...column1Items, ...column2Items].find((i) => i.id === confirmDelete.itemId)?.label ||
            'this item'
          }"`}
          explanation="This will remove the item and any matches connected to it. This cannot be undone."
          deleteHandler={confirmDeleteItem}
          cancelHandler={() => setConfirmDelete(null)}
        />
      )}

      {itemEditor.open && (
        <MatchingItemEditorModal
          show={itemEditor.open}
          initialItem={itemEditor.item}
          existingLabels={allLabelsExcept(itemEditor.item?.id)}
          projectSlug={projectSlug}
          onSave={handleItemSave}
          onCancel={() => setItemEditor({ open: false, col: 1, item: null })}
        />
      )}
    </div>
  );

  return (
    <AdvancedAuthoringModal
      show={show}
      onHide={onCancel}
      size="xl"
      dialogClassName="matching-author-modal-dialog"
    >
      <Modal.Header closeButton>
        <Modal.Title>Manage Matching</Modal.Title>
      </Modal.Header>
      <Modal.Body className="p-0">{body}</Modal.Body>
      <Modal.Footer>
        <button type="button" className="btn btn-secondary" onClick={onCancel}>
          Cancel
        </button>
        <button type="button" className="btn btn-primary" onClick={handleSave}>
          Save
        </button>
      </Modal.Footer>
    </AdvancedAuthoringModal>
  );
};

export default MatchingAuthorModal;
