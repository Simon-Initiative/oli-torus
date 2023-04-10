import React, { useCallback, useMemo } from 'react';
import { v4 } from 'uuid';
import * as ContentModel from 'data/content/model/elements/types';
import { InlineEditor } from '../common/settings/InlineEditor';
import { CommandContext } from '../commands/interfaces';

import { Model } from '../../../../data/content/model/elements/factories';

import { PronunciationEditor } from '../PronunciationEditor';

export const DefinitionInlineEditor: React.FC<{
  definition: ContentModel.Definition;
  commandContext: CommandContext;
  onEdit: (definition: Partial<ContentModel.Definition>) => void;
}> = ({ definition, onEdit, commandContext }) => {
  const onEditTerm = (event: React.ChangeEvent<HTMLInputElement>) => {
    onEdit({ term: event.target.value });
  };

  // Need unique ID's in case there's more than one definition editor on screen
  const termId = useMemo(() => v4(), []);

  const onPronunciationEdit = useCallback(
    (newVal) => {
      onEdit({
        ...definition,
        pronunciation: newVal,
      });
    },
    [definition, onEdit],
  );

  const onMeaningEdit = useCallback(
    (targetIndex: number) => (edit: (ContentModel.Block | ContentModel.TextBlock)[]) => {
      const meanings = definition.meanings.map((meaning, index) => {
        if (index === targetIndex) {
          return {
            ...meaning,
            children: edit,
          };
        }
        return meaning;
      });

      onEdit({ meanings });
    },
    [definition.meanings, onEdit],
  );

  const onDeleteMeaning = useCallback(
    (targetIndex: number) => () => {
      const meanings = definition.meanings.filter((meaning, index) => index !== targetIndex);
      onEdit({ meanings });
      return false;
    },
    [definition.meanings, onEdit],
  );

  const onNewMeaning = useCallback(() => {
    onEdit({
      meanings: [...definition.meanings, Model.definitionMeaning()],
    });
    return false;
  }, [definition.meanings, onEdit]);

  const onTranslationEdit = useCallback(
    (targetIndex: number) => (edit: ContentModel.TextBlock[]) => {
      const translations = definition.translations.map((translation, index) => {
        if (index === targetIndex) {
          return {
            ...translation,
            children: edit,
          };
        }
        return translation;
      });

      onEdit({ translations });
    },
    [definition.translations, onEdit],
  );

  const onNewTranslation = useCallback(() => {
    onEdit({
      translations: [...definition.translations, Model.definitionTranslation()],
    });
  }, [definition.translations, onEdit]);

  const onDeleteTranslation = useCallback(
    (targetIndex: number) => () => {
      const translations = definition.translations.filter((t, index) => index !== targetIndex);
      onEdit({ translations });
    },
    [definition.translations, onEdit],
  );

  return (
    <div className="definition-editor">
      <div className="form-group">
        <label htmlFor={termId}>Term</label>
        <input
          type="text"
          id={termId}
          value={definition.term}
          onChange={onEditTerm}
          className="form-control"
        />
      </div>
      <div className="form-group">
        <label>Definitions</label>
        {definition.meanings.map((meaning: ContentModel.DefinitionMeaning, index: number) => (
          <div key={`definition-${index}-${meaning.id}`} className="definition-row">
            <div className="definition-number">{index + 1}. </div>
            <div className="form-control definition-input">
              <InlineEditor
                allowBlockElements={true}
                commandContext={commandContext}
                content={Array.isArray(meaning.children) ? meaning.children : []}
                onEdit={onMeaningEdit(index)}
              />
            </div>
            <button
              className="btn btn-outline-danger delete-btn"
              type="button"
              onClick={onDeleteMeaning(index)}
            >
              <i className="fa-solid fa-trash"></i>
            </button>
          </div>
        ))}
        <div className="definition-row">
          <div className="definition-number">{definition.meanings.length + 1}. </div>
          <button className="btn btn-outline-success" type="button" onClick={onNewMeaning}>
            Add
          </button>
        </div>
      </div>
      <div className="form-group">
        <label>
          Translations <small className="text-muted">Optional</small>
        </label>
        {definition.translations.map(
          (translation: ContentModel.DefinitionTranslation, index: number) => (
            <div key={`definition-${index}-${translation.id}`} className="definition-row">
              <div className="definition-number">{index + 1}. </div>
              <div className="form-control definition-input">
                <InlineEditor
                  commandContext={commandContext}
                  content={Array.isArray(translation.children) ? translation.children : []}
                  onEdit={onTranslationEdit(index)}
                />
              </div>
              <button
                className="btn btn-outline-danger delete-btn"
                type="button"
                onClick={onDeleteTranslation(index)}
              >
                <i className="fa-solid fa-trash"></i>
              </button>
            </div>
          ),
        )}
        <button className="btn btn-outline-success" type="button" onClick={onNewTranslation}>
          Add
        </button>
      </div>
      <PronunciationEditor
        commandContext={commandContext}
        pronunciation={definition.pronunciation}
        onEdit={onPronunciationEdit}
      />
    </div>
  );
};
