import React, { useCallback, useMemo, useRef } from 'react';
import { v4 } from 'uuid';
import * as ContentModel from 'data/content/model/elements/types';
import { InlineEditor } from '../common/settings/InlineEditor';
import { CommandContext } from '../commands/interfaces';

import { Model } from '../../../../data/content/model/elements/factories';
import { selectAudio } from './definitionActions';

export const DefinitionInlineEditor: React.FC<{
  definition: ContentModel.Definition;
  commandContext: CommandContext;
  onEdit: (definition: Partial<ContentModel.Definition>) => void;
}> = ({ definition, onEdit, commandContext }) => {
  const previewPlayer = useRef<HTMLAudioElement>(null);
  const onEditTerm = (event: React.ChangeEvent<HTMLInputElement>) => {
    onEdit({ term: event.target.value });
  };

  // Need unique ID's in case there's more than one definition editor on screen
  const termId = useMemo(() => v4(), []);
  const pronunciationId = useMemo(() => v4(), []);

  const onPronunciationEdit = useCallback(
    (edit: ContentModel.TextBlock[]) => {
      if (definition.pronunciation) {
        onEdit({
          pronunciation: {
            ...definition.pronunciation,
            children: edit,
          },
        });
      } else {
        onEdit({ pronunciation: Model.definitionPronunciation({ children: edit }) });
      }
    },
    [definition.pronunciation, onEdit],
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

  const onChangeAudio = useCallback(() => {
    selectAudio(commandContext.projectSlug, definition.pronunciation?.src).then(
      ({ url, contenttype }: ContentModel.AudioSource) => {
        onEdit({ pronunciation: { ...definition.pronunciation, src: url, contenttype } });
      },
    );
  }, [commandContext.projectSlug, definition.pronunciation, onEdit]);

  const onPreviewAudio = useCallback(() => {
    if (!previewPlayer.current) return;
    if (previewPlayer.current.paused) {
      previewPlayer.current.currentTime = 0;
      previewPlayer.current.play();
    } else {
      previewPlayer.current.pause();
    }
  }, []);

  const onRemoveAudio = useCallback(() => {
    previewPlayer.current?.pause();
    onEdit({
      pronunciation: { ...definition.pronunciation, src: '', contenttype: '' },
    });
  }, [definition.pronunciation, onEdit]);

  return (
    <div>
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
              <span className="material-icons">delete</span>
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
                <span className="material-icons">delete</span>
              </button>
            </div>
          ),
        )}
        <button className="btn btn-outline-success" type="button" onClick={onNewTranslation}>
          Add
        </button>
      </div>

      <div className="form-group">
        <label htmlFor={pronunciationId}>
          Pronunciation <small className="text-muted">Optional</small>
        </label>

        <div className="form-control definition-input">
          <InlineEditor
            id={pronunciationId}
            commandContext={commandContext}
            placeholder=""
            content={
              Array.isArray(definition.pronunciation?.children)
                ? definition.pronunciation.children
                : []
            }
            onEdit={onPronunciationEdit}
          />
        </div>

        {definition.pronunciation && (
          <div className="definition-row audio-row">
            <label>Pronunciation Audio: </label>
            <button
              onClick={onChangeAudio}
              type="button"
              className="btn btn-outline-secondary btn-pronunciation-audio"
            >
              <span className="material-icons ">folder</span>
            </button>
            {definition.pronunciation?.src && (
              <>
                <audio src={definition.pronunciation?.src} ref={previewPlayer} />
                <button
                  type="button"
                  onClick={onPreviewAudio}
                  className="btn btn-outline-success btn-pronunciation-audio "
                >
                  <span className="material-icons">play_circle</span>
                </button>
                <button
                  type="button"
                  onClick={onRemoveAudio}
                  className="btn btn-outline-danger btn-pronunciation-audio "
                >
                  <span className="material-icons">delete</span>
                </button>
              </>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
