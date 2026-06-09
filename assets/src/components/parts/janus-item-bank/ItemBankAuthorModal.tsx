import React, { useEffect, useRef, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { AdvancedAuthoringModal } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import ConfirmDelete from '../../../apps/authoring/components/Modal/DeleteConfirmationModal';
import ItemEditorModal from './ItemEditorModal';
import './ItemBankAuthorModal.scss';
import { BANK_ID, Placements, categoryTitle, genId, itemDisplayText } from './grouping-util';
import { GroupingCategory, GroupingItem, GroupingModel } from './schema';

type AuthorMode = 'manage' | 'answer';

export interface ItemBankAuthorModalProps {
  show: boolean;
  model: Pick<GroupingModel, 'items' | 'categories' | 'layoutPlacements' | 'correctAnswer'>;
  projectSlug: string;
  onSave: (
    snapshot: Pick<GroupingModel, 'items' | 'categories' | 'layoutPlacements' | 'correctAnswer'>,
  ) => void;
  onCancel: () => void;
}

interface DragItemProps {
  item: GroupingItem;
  showActions: boolean;
  onDragStart: (e: React.DragEvent) => void;
  onEdit: () => void;
  onDelete: () => void;
}

interface EditableGroupHeaderProps {
  title: string;
  fallbackTitle: string;
  editable?: boolean;
  onRename: (title: string) => void;
}

const EditableGroupHeader: React.FC<EditableGroupHeaderProps> = ({
  title,
  fallbackTitle,
  editable = true,
  onRename,
}) => {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(title);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!editing) {
      setDraft(title);
    }
  }, [title, editing]);

  useEffect(() => {
    if (editing) {
      inputRef.current?.focus();
      inputRef.current?.select();
    }
  }, [editing]);

  const commit = () => {
    onRename(draft.trim() || fallbackTitle);
    setEditing(false);
  };

  const cancel = () => {
    setDraft(title);
    setEditing(false);
  };

  if (!editable) {
    return <span className="ibam-col-title">{title}</span>;
  }

  if (editing) {
    return (
      <input
        ref={inputRef}
        className="ibam-col-title-input"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={commit}
        onKeyDown={(e) => {
          if (e.key === 'Enter') {
            e.preventDefault();
            commit();
          } else if (e.key === 'Escape') {
            e.preventDefault();
            cancel();
          }
        }}
        onClick={(e) => e.stopPropagation()}
        aria-label="Category name"
      />
    );
  }

  return (
    <button
      type="button"
      className="ibam-col-title ibam-col-title-btn"
      onClick={() => setEditing(true)}
      title="Click to rename"
    >
      {title}
    </button>
  );
};

const DragHandle: React.FC = () => (
  <span className="ibam-drag-handle" aria-hidden="true">
    <span className="ibam-drag-dot" />
    <span className="ibam-drag-dot" />
    <span className="ibam-drag-dot" />
    <span className="ibam-drag-dot" />
    <span className="ibam-drag-dot" />
    <span className="ibam-drag-dot" />
  </span>
);

const DragItem: React.FC<DragItemProps> = ({
  item,
  showActions,
  onDragStart,
  onEdit,
  onDelete,
}) => (
  <div className="ibam-item" draggable onDragStart={onDragStart}>
    <DragHandle />
    {item.type === 'image' && item.imageSrc ? (
      <img className="ibam-item-thumb" src={item.imageSrc} alt={item.alt || item.label} />
    ) : null}
    <span className="ibam-item-label">{itemDisplayText(item)}</span>
    {showActions && (
      <div className="ibam-item-actions">
        <button type="button" className="ibam-iab" title="Edit item" onClick={onEdit}>
          ✎
        </button>
        <button type="button" className="ibam-iab del" title="Delete" onClick={onDelete}>
          ✕
        </button>
      </div>
    )}
  </div>
);

interface BankColumnProps {
  zoneItems: GroupingItem[];
  showActions: boolean;
  onDrop: (itemId: string, zoneId: string) => void;
  onItemEdit: (item: GroupingItem) => void;
  onItemDelete: (id: string) => void;
}

const BankColumn: React.FC<BankColumnProps> = ({
  zoneItems,
  showActions,
  onDrop,
  onItemEdit,
  onItemDelete,
}) => {
  const [over, setOver] = useState(false);

  return (
    <div className="ibam-bank-column">
      <div className="ibam-col-header header-bank">Item Bank</div>
      <div
        className={`ibam-dropzone zone-bank${over ? ' over' : ''}`}
        onDragOver={(e) => {
          e.preventDefault();
          setOver(true);
        }}
        onDragLeave={(e) => {
          if (!e.currentTarget.contains(e.relatedTarget as Node)) {
            setOver(false);
          }
        }}
        onDrop={(e) => {
          e.preventDefault();
          setOver(false);
          const itemId = e.dataTransfer.getData('text/plain');
          if (itemId) {
            onDrop(itemId, BANK_ID);
          }
        }}
      >
        {zoneItems.map((item) => (
          <DragItem
            key={item.id}
            item={item}
            showActions={showActions}
            onDragStart={(e) => e.dataTransfer.setData('text/plain', item.id)}
            onEdit={() => onItemEdit(item)}
            onDelete={() => onItemDelete(item.id)}
          />
        ))}
        {zoneItems.length === 0 && (
          <div className="ibam-empty-hint">
            <span>Click &ldquo;+ Add item&rdquo; to start</span>
          </div>
        )}
      </div>
    </div>
  );
};

interface GroupColumnProps {
  category: GroupingCategory;
  categoryIndex: number;
  zoneItems: GroupingItem[];
  showActions: boolean;
  onDrop: (itemId: string, zoneId: string) => void;
  onRenameCategory: (id: string, title: string) => void;
  onRemoveCategory: (id: string) => void;
  onItemEdit: (item: GroupingItem) => void;
  onItemDelete: (id: string) => void;
}

const GroupColumn: React.FC<GroupColumnProps> = ({
  category,
  categoryIndex,
  zoneItems,
  showActions,
  onDrop,
  onRenameCategory,
  onRemoveCategory,
  onItemEdit,
  onItemDelete,
}) => {
  const [over, setOver] = useState(false);
  const headerTitle = categoryTitle(category, categoryIndex);
  const fallbackTitle = `Category ${categoryIndex + 1}`;

  return (
    <div className="ibam-group-column">
      <div className="ibam-col-header header-group">
        <EditableGroupHeader
          title={headerTitle}
          fallbackTitle={fallbackTitle}
          editable={showActions}
          onRename={(title) => onRenameCategory(category.id, title)}
        />
        {showActions && (
          <button
            type="button"
            className="ibam-col-del"
            aria-label={`Remove ${headerTitle}`}
            onClick={() => onRemoveCategory(category.id)}
          >
            ×
          </button>
        )}
      </div>
      <div
        className={`ibam-dropzone zone-group${over ? ' over' : ''}`}
        onDragOver={(e) => {
          e.preventDefault();
          setOver(true);
        }}
        onDragLeave={(e) => {
          if (!e.currentTarget.contains(e.relatedTarget as Node)) {
            setOver(false);
          }
        }}
        onDrop={(e) => {
          e.preventDefault();
          setOver(false);
          const itemId = e.dataTransfer.getData('text/plain');
          if (itemId) {
            onDrop(itemId, category.id);
          }
        }}
      >
        {zoneItems.map((item) => (
          <DragItem
            key={item.id}
            item={item}
            showActions={showActions}
            onDragStart={(e) => e.dataTransfer.setData('text/plain', item.id)}
            onEdit={() => onItemEdit(item)}
            onDelete={() => onItemDelete(item.id)}
          />
        ))}
        {zoneItems.length === 0 && (
          <div className="ibam-empty-hint">
            <span>Drop items here</span>
          </div>
        )}
      </div>
    </div>
  );
};

const purgeZoneFromPlacements = (placements: Placements, zoneId: string): Placements => {
  const next = { ...placements };
  Object.keys(next).forEach((itemId) => {
    if (next[itemId] === zoneId) {
      delete next[itemId];
    }
  });
  return next;
};

const ItemBankAuthorModal: React.FC<ItemBankAuthorModalProps> = ({
  show,
  model,
  projectSlug,
  onSave,
  onCancel,
}) => {
  const [mode, setMode] = useState<AuthorMode>('manage');
  const [items, setItems] = useState<GroupingItem[]>([]);
  const [categories, setCategories] = useState<GroupingCategory[]>([]);
  const [layoutPlacements, setLayoutPlacements] = useState<Placements>({});
  const [correctAnswer, setCorrectAnswer] = useState<Placements>({});
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [itemEditor, setItemEditor] = useState<{ open: boolean; item: GroupingItem | null }>({
    open: false,
    item: null,
  });
  const categoryCounter = useRef(3);

  useEffect(() => {
    if (show) {
      setMode('manage');
      setItems(model.items || []);
      setCategories(model.categories || []);
      setLayoutPlacements(model.layoutPlacements || {});
      setCorrectAnswer(model.correctAnswer || {});
      setConfirmDeleteId(null);
      setItemEditor({ open: false, item: null });
    }
  }, [show, model]);

  const activePlacements = mode === 'answer' ? correctAnswer : layoutPlacements;
  const showItemActions = mode === 'manage';

  const itemsInZone = (zoneId: string): GroupingItem[] => {
    if (zoneId === BANK_ID) {
      return items.filter((i) => !activePlacements[i.id]);
    }
    return items.filter((i) => activePlacements[i.id] === zoneId);
  };

  const handleDrop = (itemId: string, zoneId: string) => {
    const setter = mode === 'answer' ? setCorrectAnswer : setLayoutPlacements;
    setter((prev) => {
      const next = { ...prev };
      if (zoneId === BANK_ID) {
        delete next[itemId];
      } else {
        next[itemId] = zoneId;
      }
      return next;
    });
  };

  const addCategory = () => {
    setCategories((prev) => [
      ...prev,
      { id: genId('category'), title: `Category ${categoryCounter.current++}` },
    ]);
  };

  const renameCategory = (id: string, title: string) => {
    setCategories((prev) => prev.map((c) => (c.id === id ? { ...c, title } : c)));
  };

  const removeCategory = (id: string) => {
    setCategories((prev) => prev.filter((c) => c.id !== id));
    setLayoutPlacements((prev) => purgeZoneFromPlacements(prev, id));
    setCorrectAnswer((prev) => purgeZoneFromPlacements(prev, id));
  };

  const handleItemSave = (item: GroupingItem) => {
    setItems((prev) =>
      prev.some((i) => i.id === item.id)
        ? prev.map((i) => (i.id === item.id ? item : i))
        : [...prev, item],
    );
    setItemEditor({ open: false, item: null });
  };

  const confirmDelete = () => {
    if (!confirmDeleteId) {
      return;
    }
    setItems((prev) => prev.filter((i) => i.id !== confirmDeleteId));
    setLayoutPlacements((prev) => {
      const next = { ...prev };
      delete next[confirmDeleteId];
      return next;
    });
    setCorrectAnswer((prev) => {
      const next = { ...prev };
      delete next[confirmDeleteId];
      return next;
    });
    setConfirmDeleteId(null);
  };

  const handleSave = () => {
    onSave({ items, categories, layoutPlacements, correctAnswer });
  };

  const placedCount = Object.keys(correctAnswer).length;
  const bottomMsg =
    mode === 'manage'
      ? 'Add items, create categories, and arrange the layout. Switch to Set Correct Answer when ready.'
      : 'Drag items from the bank into categories to define the correct answer, then click Save.';

  const body = (
    <div className={`item-bank-author-modal ibam-mode-${mode}`}>
      <div className="ibam-toolbar">
        <div className="ibam-mode-switch" role="tablist" aria-label="Item bank mode">
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'manage'}
            className={`ibam-mode-option${mode === 'manage' ? ' active' : ''}`}
            onClick={() => setMode('manage')}
          >
            Edit Mode
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={mode === 'answer'}
            className={`ibam-mode-option${mode === 'answer' ? ' active active-answer' : ''}`}
            onClick={() => setMode('answer')}
          >
            Set Correct Answer
          </button>
        </div>
        {mode === 'manage' && (
          <div className="ibam-toolbar-actions">
            <button
              type="button"
              className="ibam-tb-link"
              onClick={() => setItemEditor({ open: true, item: null })}
            >
              + Add item
            </button>
            <button type="button" className="ibam-tb-link" onClick={addCategory}>
              + Add category
            </button>
          </div>
        )}
        {mode === 'answer' && (
          <span className="ibam-answer-mode-label">Correct answer placement</span>
        )}
        <div className="ibam-spacer" />
      </div>

      <div className="ibam-columns-wrap">
        <BankColumn
          zoneItems={itemsInZone(BANK_ID)}
          showActions={showItemActions}
          onDrop={handleDrop}
          onItemEdit={(item) => setItemEditor({ open: true, item })}
          onItemDelete={setConfirmDeleteId}
        />
        <div className="ibam-groups-row">
          {categories.map((category, idx) => (
            <GroupColumn
              key={category.id}
              category={category}
              categoryIndex={idx}
              zoneItems={itemsInZone(category.id)}
              showActions={showItemActions}
              onDrop={handleDrop}
              onRenameCategory={renameCategory}
              onRemoveCategory={removeCategory}
              onItemEdit={(item) => setItemEditor({ open: true, item })}
              onItemDelete={setConfirmDeleteId}
            />
          ))}
        </div>
      </div>

      <div className="ibam-bottombar">
        <span className="ibam-bottom-hint">{bottomMsg}</span>
        <span className="ibam-status-pill">
          {items.length} item{items.length !== 1 ? 's' : ''} · {categories.length} categor
          {categories.length !== 1 ? 'ies' : 'y'}
          {mode === 'answer' ? ` · ${placedCount} placed` : ''}
        </span>
      </div>

      {confirmDeleteId && (
        <ConfirmDelete
          show={!!confirmDeleteId}
          elementType="item"
          elementName={`"${items.find((i) => i.id === confirmDeleteId)?.label || 'this item'}"`}
          explanation="This will remove the item from all categories. This cannot be undone."
          deleteHandler={confirmDelete}
          cancelHandler={() => setConfirmDeleteId(null)}
        />
      )}

      {itemEditor.open && (
        <ItemEditorModal
          show={itemEditor.open}
          initialItem={itemEditor.item}
          existingLabels={items
            .filter((i) => i.id !== itemEditor.item?.id)
            .map((i) => i.label.trim().toLowerCase())}
          projectSlug={projectSlug}
          onSave={handleItemSave}
          onCancel={() => setItemEditor({ open: false, item: null })}
        />
      )}
    </div>
  );

  return (
    <AdvancedAuthoringModal
      show={show}
      onHide={onCancel}
      size="xl"
      dialogClassName="item-bank-author-modal-dialog"
    >
      <Modal.Header closeButton>
        <Modal.Title>Manage Item Bank</Modal.Title>
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

export default ItemBankAuthorModal;
