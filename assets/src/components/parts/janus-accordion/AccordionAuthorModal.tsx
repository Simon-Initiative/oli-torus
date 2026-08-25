import React, { memo, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Modal } from 'react-bootstrap';
import { JanusRichLabelEditor } from 'components/parts/common/JanusRichLabelEditor';
import { MarkupTree } from 'components/parts/janus-text-flow/TextFlow';
import guid from 'utils/guid';
import { htmlToPlainText, normalizeRichLabelForStorage } from 'utils/richOptionLabel';
import { AdvancedAuthoringModal } from '../../../apps/authoring/components/AdvancedAuthoringModal';
import ConfirmDelete from '../../../apps/authoring/components/Modal/DeleteConfirmationModal';
import { tagName as quillEditorTagName, registerEditor } from '../janus-text-flow/QuillEditor';
import './AccordionAuthorModal.scss';
import { getSectionPreviewText } from './accordion-util';
import { AccordionSection, MAX_ACCORDION_SECTIONS, createDefaultSection } from './schema';

export interface AccordionAuthorModalProps {
  show: boolean;
  sections: AccordionSection[];
  onSave: (sections: AccordionSection[]) => void;
  onCancel: () => void;
}

type AccordionSectionContentEditorProps = {
  sectionId: string;
  contentNodes: MarkupTree[];
};

const AccordionSectionContentEditor = memo(function AccordionSectionContentEditor({
  sectionId,
  contentNodes,
}: AccordionSectionContentEditorProps) {
  return (
    <div className="acc-modal-quill-wrap" data-field="content" data-section-id={sectionId}>
      {React.createElement(quillEditorTagName, {
        key: `${sectionId}-content`,
        tree: JSON.stringify(contentNodes || []),
        showimagecontrol: true,
      })}
    </div>
  );
});

const AccordionAuthorModal: React.FC<AccordionAuthorModalProps> = ({
  show,
  sections: initialSections,
  onSave,
  onCancel,
}) => {
  const [draftSections, setDraftSections] = useState<AccordionSection[]>(initialSections);
  const [activeSectionId, setActiveSectionId] = useState<string | null>(
    initialSections[0]?.id ?? null,
  );
  const [confirmDeleteId, setConfirmDeleteId] = useState<string | null>(null);
  const [titleDraft, setTitleDraft] = useState('');
  const editorChangeDebounce = useRef<number | null>(null);
  const titleCommitDebounce = useRef<number | null>(null);
  const titleDraftRef = useRef('');
  const activeSectionIdRef = useRef<string | null>(activeSectionId);

  useEffect(() => {
    activeSectionIdRef.current = activeSectionId;
  }, [activeSectionId]);

  useEffect(() => {
    titleDraftRef.current = titleDraft;
  }, [titleDraft]);

  useEffect(() => {
    registerEditor();
  }, []);

  const commitTitleToSection = useCallback((sectionId: string, title: string) => {
    const normalized = normalizeRichLabelForStorage(title);
    setDraftSections((sections) =>
      sections.map((s) => (s.id === sectionId ? { ...s, title: normalized } : s)),
    );
  }, []);

  const flushTitleDraft = useCallback(
    (sectionId: string | null = activeSectionIdRef.current) => {
      if (!sectionId) return;
      if (titleCommitDebounce.current) {
        window.clearTimeout(titleCommitDebounce.current);
        titleCommitDebounce.current = null;
      }
      commitTitleToSection(sectionId, titleDraftRef.current);
    },
    [commitTitleToSection],
  );

  const activeSection = useMemo(
    () => draftSections.find((s) => s.id === activeSectionId),
    [draftSections, activeSectionId],
  );

  const activeSectionIndex = useMemo(
    () => draftSections.findIndex((s) => s.id === activeSectionId),
    [draftSections, activeSectionId],
  );

  useEffect(() => {
    if (!activeSectionId) {
      setTitleDraft('');
      return;
    }
    const section = draftSections.find((s) => s.id === activeSectionId);
    setTitleDraft(section?.title ?? '');
    // Only reset local title when switching sections, not on debounced commits.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeSectionId]);

  useEffect(() => {
    const handleEditorChange = (e: any) => {
      const wrapper = (e.target as HTMLElement | null)?.closest(
        '[data-section-id]',
      ) as HTMLElement | null;
      const field = wrapper?.dataset.field;
      const sectionId = wrapper?.dataset.sectionId;
      if (!field || !sectionId) return;

      const nodes = e.detail?.payload?.value;
      if (!nodes) return;

      if (editorChangeDebounce.current) {
        window.clearTimeout(editorChangeDebounce.current);
      }

      editorChangeDebounce.current = window.setTimeout(() => {
        if (field === 'content') {
          setDraftSections((sections) =>
            sections.map((s) => (s.id === sectionId ? { ...s, contentNodes: nodes } : s)),
          );
        }
      }, 300);
    };

    document.addEventListener(`${quillEditorTagName}-change`, handleEditorChange);
    return () => {
      document.removeEventListener(`${quillEditorTagName}-change`, handleEditorChange);
      if (editorChangeDebounce.current) {
        window.clearTimeout(editorChangeDebounce.current);
      }
      if (titleCommitDebounce.current) {
        window.clearTimeout(titleCommitDebounce.current);
      }
    };
  }, []);

  const handleTitleChange = useCallback(
    (title: string) => {
      setTitleDraft(title);
      if (!activeSectionIdRef.current) return;

      if (titleCommitDebounce.current) {
        window.clearTimeout(titleCommitDebounce.current);
      }

      titleCommitDebounce.current = window.setTimeout(() => {
        if (activeSectionIdRef.current) {
          commitTitleToSection(activeSectionIdRef.current, title);
        }
      }, 200);
    },
    [commitTitleToSection],
  );

  const handleTitleBlur = useCallback(() => {
    flushTitleDraft();
  }, [flushTitleDraft]);

  const selectSection = useCallback(
    (sectionId: string) => {
      if (sectionId === activeSectionIdRef.current) return;
      flushTitleDraft();
      setActiveSectionId(sectionId);
    },
    [flushTitleDraft],
  );

  const addSection = useCallback(() => {
    if (draftSections.length >= MAX_ACCORDION_SECTIONS) return;
    flushTitleDraft();
    const section = createDefaultSection(draftSections.length + 1, `accordion-section-${guid()}`);
    setDraftSections((s) => [...s, section]);
    setActiveSectionId(section.id);
  }, [draftSections.length, flushTitleDraft]);

  const deleteSection = useCallback(
    (sectionId: string) => {
      setDraftSections((sections) => {
        const next = sections.filter((s) => s.id !== sectionId);
        if (activeSectionId === sectionId) {
          setActiveSectionId(next[0]?.id ?? null);
        }
        return next;
      });
    },
    [activeSectionId],
  );

  const confirmDelete = useCallback(() => {
    if (!confirmDeleteId) return;
    deleteSection(confirmDeleteId);
    setConfirmDeleteId(null);
  }, [confirmDeleteId, deleteSection]);

  const handleSave = useCallback(() => {
    if (editorChangeDebounce.current) {
      window.clearTimeout(editorChangeDebounce.current);
      editorChangeDebounce.current = null;
    }
    if (titleCommitDebounce.current) {
      window.clearTimeout(titleCommitDebounce.current);
      titleCommitDebounce.current = null;
    }

    const finalSections = draftSections.map((s) => {
      if (s.id === activeSectionIdRef.current) {
        return { ...s, title: normalizeRichLabelForStorage(titleDraftRef.current) };
      }
      return s;
    });
    onSave(finalSections);
  }, [draftSections, onSave]);

  const atSectionLimit = draftSections.length >= MAX_ACCORDION_SECTIONS;
  const sectionCountLabel = `${draftSections.length} ${
    draftSections.length === 1 ? 'section' : 'sections'
  }`;

  const confirmDeleteIndex = confirmDeleteId
    ? draftSections.findIndex((s) => s.id === confirmDeleteId)
    : -1;
  const confirmDeleteName =
    confirmDeleteIndex >= 0 ? `Section ${confirmDeleteIndex + 1}` : 'this section';

  const body = (
    <div className="accordion-author-modal-content">
      <div className="acc-modal-body">
        <aside className="acc-modal-list">
          <button
            type="button"
            className="acc-modal-add-btn"
            onClick={addSection}
            disabled={atSectionLimit}
          >
            + Add section
          </button>
          {atSectionLimit ? (
            <p className="acc-modal-section-limit">Maximum of 10 sections</p>
          ) : null}

          <div className="acc-modal-section-list">
            {draftSections.map((section, index) => {
              const previewText = getSectionPreviewText(section.contentNodes) || 'Empty content';
              const titlePreview = htmlToPlainText(section.title) || `Section ${index + 1}`;

              return (
                <div
                  key={section.id}
                  className={`acc-modal-section-item${
                    section.id === activeSectionId ? ' is-active' : ''
                  }`}
                  role="button"
                  tabIndex={0}
                  onClick={() => selectSection(section.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      selectSection(section.id);
                    }
                  }}
                >
                  <div className="acc-modal-section-body">
                    <div className="acc-modal-section-item-header">
                      <span className="acc-modal-section-item-title">SECTION {index + 1}</span>
                      {draftSections.length > 1 && (
                        <button
                          type="button"
                          className="acc-modal-section-delete"
                          aria-label="Delete section"
                          title="Delete section"
                          onClick={(e) => {
                            e.stopPropagation();
                            setConfirmDeleteId(section.id);
                          }}
                        >
                          <i className="fa fa-trash-alt" aria-hidden="true" />
                        </button>
                      )}
                    </div>
                    <span className="acc-modal-section-preview">{titlePreview}</span>
                    <span className="acc-modal-section-preview">{previewText}</span>
                  </div>
                </div>
              );
            })}
          </div>
        </aside>

        <main className="acc-modal-editor">
          {activeSection && activeSectionId ? (
            <>
              <h4 className="acc-modal-editor-heading">Editing Section {activeSectionIndex + 1}</h4>

              <div className="acc-modal-title-field">
                <div className="acc-modal-field-label">Title</div>
                <div onBlur={handleTitleBlur}>
                  <JanusRichLabelEditor
                    value={titleDraft}
                    onChange={handleTitleChange}
                    minHeight={72}
                  />
                </div>
              </div>

              <div className="acc-modal-content-field">
                <div className="acc-modal-field-label">Content</div>
                <AccordionSectionContentEditor
                  sectionId={activeSectionId}
                  contentNodes={activeSection.contentNodes}
                />
              </div>
            </>
          ) : (
            <div className="acc-modal-editor-empty">No section selected</div>
          )}
        </main>
      </div>

      {confirmDeleteId && (
        <ConfirmDelete
          show={!!confirmDeleteId}
          elementType="section"
          elementName={`"${confirmDeleteName}"`}
          explanation="This cannot be undone."
          deleteHandler={confirmDelete}
          cancelHandler={() => setConfirmDeleteId(null)}
        />
      )}
    </div>
  );

  return (
    <AdvancedAuthoringModal
      show={show}
      onHide={onCancel}
      size="xl"
      dialogClassName="accordion-author-modal-dialog"
    >
      <Modal.Header closeButton>
        <Modal.Title>
          Accordion Sections
          <span className="acc-modal-title-count"> · {sectionCountLabel}</span>
        </Modal.Title>
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

export default AccordionAuthorModal;
