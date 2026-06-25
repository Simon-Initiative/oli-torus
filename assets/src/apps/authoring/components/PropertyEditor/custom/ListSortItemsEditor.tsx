import React, { useCallback, useState } from 'react';
import { useDispatch } from 'react-redux';
import { setCurrentPartPropertyFocus } from 'apps/authoring/store/parts/slice';
import guid from 'utils/guid';
import { useToggle } from '../../../../../components/hooks/useToggle';
import { AdvancedAuthoringModal } from '../../AdvancedAuthoringModal';

interface ListSortItem {
  id: string;
  text: string;
}

interface Props {
  id: string;
  value: ListSortItem[];
  onChange: (value: ListSortItem[]) => void;
  onBlur: (id: string, value: ListSortItem[]) => void;
}

const makeItem = (text = ''): ListSortItem => ({ id: `item-${guid()}`, text });

const GripIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
    <path d="M10 4H8v4h2V4zm6 0h-2v4h2V4zm-6 7H8v4h2v-4zm6 0h-2v4h2v-4zm-6 7H8v4h2v-4zm6 0h-2v4h2v-4z" />
  </svg>
);

const CloseIcon = () => (
  <svg
    width="18"
    height="18"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    aria-hidden="true"
  >
    <path d="M18 6L6 18M6 6l12 12" />
  </svg>
);

const PlusIcon = () => (
  <svg
    width="20"
    height="20"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    aria-hidden="true"
  >
    <path d="M12 5v14m-7-7h14" />
  </svg>
);

const modalStyles = `
.lsi-modal .modal-content {
  border-radius: 16px;
  overflow: hidden;
  border: none;
}
.lsi-root { font-family: inherit; }
.lsi-header {
  padding: 20px 24px;
  border-bottom: 1px solid #f1f5f9;
}
.lsi-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #1e293b;
  margin: 0;
}
.lsi-subtitle {
  font-size: 0.875rem;
  color: #64748b;
  margin: 4px 0 0;
}
.lsi-body {
  padding: 16px 24px;
  max-height: 60vh;
  overflow-y: auto;
}
.lsi-row {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 8px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  margin-bottom: 12px;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}
.lsi-row:hover {
  border-color: #93c5fd;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}
.lsi-row.lsi-row--dragging {
  border-color: #60a5fa;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  opacity: 0.6;
}
.lsi-handle {
  display: flex;
  align-items: center;
  color: #94a3b8;
  cursor: grab;
  padding: 0 4px;
  transition: color 0.15s ease;
}
.lsi-handle:active { cursor: grabbing; }
.lsi-row:hover .lsi-handle { color: #3b82f6; }
.lsi-index {
  font-size: 0.75rem;
  font-weight: 600;
  color: #94a3b8;
  width: 16px;
  text-align: center;
}
.lsi-input {
  flex: 1 1 auto;
  background: transparent;
  border: none;
  outline: none;
  box-shadow: none;
  color: #334155;
  font-size: 0.875rem;
  font-weight: 500;
  padding: 8px 0;
}
.lsi-input:focus {
  outline: none;
  box-shadow: none;
}
.lsi-input::placeholder { color: #94a3b8; }
.lsi-delete {
  display: flex;
  align-items: center;
  color: #94a3b8;
  background: none;
  border: none;
  padding: 4px;
  transition: color 0.15s ease;
}
.lsi-delete:hover { color: #ef4444; }
.lsi-add {
  width: 100%;
  padding: 12px;
  border: 2px dashed #e2e8f0;
  border-radius: 12px;
  background: transparent;
  color: #64748b;
  font-weight: 500;
  font-size: 0.875rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  transition: border-color 0.15s ease, color 0.15s ease, background 0.15s ease;
}
.lsi-add:hover {
  border-color: #60a5fa;
  color: #2563eb;
  background: #eff6ff;
}
.lsi-footer {
  padding: 16px 24px;
  background: #f8fafc;
  border-top: 1px solid #f1f5f9;
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}
.lsi-btn {
  padding: 8px 20px;
  font-weight: 500;
  font-size: 0.875rem;
  border-radius: 8px;
  border: none;
  transition: background 0.15s ease, color 0.15s ease;
}
.lsi-btn--cancel {
  background: transparent;
  color: #475569;
}
.lsi-btn--cancel:hover { background: #e2e8f0; }
.lsi-btn--save {
  background: #2563eb;
  color: #fff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.08);
}
.lsi-btn--save:hover { background: #1d4ed8; }
`;

export const ListSortItemsEditor: React.FC<Props> = ({ id, value, onChange, onBlur }) => {
  const dispatch = useDispatch();
  const [editorOpen, , openEditor, closeEditor] = useToggle(false);
  const [draftItems, setDraftItems] = useState<ListSortItem[]>([]);
  const [draggingIndex, setDraggingIndex] = useState<number | null>(null);

  const items: ListSortItem[] = Array.isArray(value) ? value : [];

  const onManage = useCallback(() => {
    setDraftItems(items.length ? items.map((i) => ({ ...i })) : [makeItem('Item 1')]);
    openEditor();
    dispatch(setCurrentPartPropertyFocus({ focus: false }));
  }, [items, openEditor, dispatch]);

  const onSave = useCallback(() => {
    const cleaned = draftItems
      .map((i) => ({ id: i.id || `item-${guid()}`, text: i.text }))
      .filter((i) => i.text.trim().length > 0);
    closeEditor();
    onChange(cleaned);
    setTimeout(() => onBlur(id, cleaned), 0);
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [draftItems, closeEditor, onChange, onBlur, id, dispatch]);

  const onCancel = useCallback(() => {
    closeEditor();
    dispatch(setCurrentPartPropertyFocus({ focus: true }));
  }, [closeEditor, dispatch]);

  const onDragStart = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      setDraggingIndex(index);
      e.dataTransfer.effectAllowed = 'move';
    },
    [],
  );

  const onDragOver = useCallback(
    (index: number) => (e: React.DragEvent<HTMLDivElement>) => {
      if (draggingIndex === null) {
        return;
      }
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
      if (draggingIndex === index) {
        return;
      }
      setDraftItems((prev) => {
        const next = Array.from(prev);
        const [moved] = next.splice(draggingIndex, 1);
        next.splice(index, 0, moved);
        return next;
      });
      setDraggingIndex(index);
    },
    [draggingIndex],
  );

  const onDragEnd = useCallback(() => {
    setDraggingIndex(null);
  }, []);

  const editText = useCallback(
    (index: number) => (e: React.ChangeEvent<HTMLInputElement>) => {
      const text = e.target.value;
      setDraftItems((prev) => prev.map((item, i) => (i === index ? { ...item, text } : item)));
    },
    [],
  );

  const removeItem = useCallback(
    (index: number) => () => {
      setDraftItems((prev) => prev.filter((_, i) => i !== index));
    },
    [],
  );

  const addItem = useCallback(() => {
    setDraftItems((prev) => [...prev, makeItem('')]);
  }, []);

  return (
    <div className="list-sort-items-editor">
      <label className="form-label">List Items</label>
      <div className="text-muted small mb-1">{items.length} item(s) defined</div>
      <button type="button" className="btn btn-primary btn-sm" onClick={onManage}>
        Manage items
      </button>

      {editorOpen && (
        <AdvancedAuthoringModal show={true} size="lg" onHide={onCancel} dialogClassName="lsi-modal">
          <style>{modalStyles}</style>
          <div className="lsi-root">
            <div className="lsi-header">
              <h2 className="lsi-title">Manage List Items</h2>
              <p className="lsi-subtitle">Drag to set order, click input to edit text.</p>
            </div>

            <div className="lsi-body">
              <div>
                {draftItems.map((item, index) => (
                  <div
                    key={item.id}
                    className={`lsi-row ${draggingIndex === index ? 'lsi-row--dragging' : ''}`}
                    draggable={true}
                    onDragStart={onDragStart(index)}
                    onDragOver={onDragOver(index)}
                    onDragEnd={onDragEnd}
                    onDrop={(e) => e.preventDefault()}
                  >
                    <span className="lsi-handle" aria-label="Drag to reorder">
                      <GripIcon />
                    </span>
                    <span className="lsi-index">{index + 1}</span>
                    <input
                      type="text"
                      className="lsi-input"
                      value={item.text}
                      onChange={editText(index)}
                      placeholder="Enter item name..."
                      draggable={false}
                      onDragStart={(e) => e.stopPropagation()}
                    />
                    <button
                      type="button"
                      className="lsi-delete"
                      onClick={removeItem(index)}
                      aria-label="Delete item"
                    >
                      <CloseIcon />
                    </button>
                  </div>
                ))}
              </div>

              <button type="button" className="lsi-add" onClick={addItem}>
                <PlusIcon />
                Add item
              </button>
            </div>

            <div className="lsi-footer">
              <button type="button" className="lsi-btn lsi-btn--cancel" onClick={onCancel}>
                Cancel
              </button>
              <button type="button" className="lsi-btn lsi-btn--save" onClick={onSave}>
                Save
              </button>
            </div>
          </div>
        </AdvancedAuthoringModal>
      )}
    </div>
  );
};

export default ListSortItemsEditor;
