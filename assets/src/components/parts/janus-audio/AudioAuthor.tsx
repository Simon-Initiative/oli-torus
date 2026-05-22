import React, { CSSProperties, useEffect, useMemo } from 'react';
import { AuthorPartComponentProps } from 'components/parts/types/parts';
import { AudioModel } from './schema';
import './Audio.scss';

const getTranscriptFileFromModel = (model: any): string => {
  if (typeof model?.transcript?.transcriptFile === 'string') {
    return model.transcript.transcriptFile;
  }
  if (typeof model?.subtitles?.transcriptFile === 'string') {
    return model.subtitles.transcriptFile;
  }
  if (typeof model?.transcriptFile === 'string') {
    return model.transcriptFile;
  }
  return '';
};

const getTranscriptTextFromModel = (model: any): string => {
  if (typeof model?.transcript?.transcriptText === 'string') {
    return model.transcript.transcriptText;
  }
  if (typeof model?.transcriptText === 'string') {
    return model.transcriptText;
  }
  return '';
};

const AudioAuthor: React.FC<AuthorPartComponentProps<AudioModel>> = (props) => {
  const { model, id } = props;
  const { width, src } = model;

  const hasTranscriptDownloads = useMemo(() => {
    const hasFile = !!getTranscriptFileFromModel(model).trim();
    const hasText = !!getTranscriptTextFromModel(model).trim();
    return hasFile || hasText;
  }, [model]);

  const containerStyles: CSSProperties = {
    width: '100%',
    height: '100%',
    display: 'flex',
    alignItems: 'center',
    cursor: 'default',
  };

  const barStyles: CSSProperties = {
    ...(width !== undefined && width !== '' ? { width } : {}),
    maxWidth: '100%',
  };

  useEffect(() => {
    // all activities *must* emit onReady
    props.onReady({ id: `${props.id}` });
  }, []);

  return (
    <div data-janus-type={tagName} style={containerStyles}>
      <div className="janus-audio-bar" style={barStyles}>
        <div className="janus-audio-bar__player">
          <audio
            id={`audioTag-${id}`}
            data-janus-type={tagName}
            className="janus-audio-element"
            style={{ width: '100%', outline: 'none', pointerEvents: 'none' }}
            controls
            controlsList="nodownload"
            tabIndex={-1}
            aria-disabled
          >
            {src ? <source src={src} /> : null}
          </audio>
        </div>
        {hasTranscriptDownloads && (
          <>
            <div style={{ width: '1px', height: '24px', backgroundColor: '#d2d6dc', flex: '0 0 auto' }} />
            <div style={{ position: 'relative', flex: '0 0 auto' }}>
              <button
                type="button"
                aria-label="Download transcript"
                title="Download transcript"
                disabled
                style={{
                  border: 'none',
                  background: 'transparent',
                  color: '#4b5563',
                  padding: '6px',
                  borderRadius: '999px',
                  cursor: 'default',
                }}
              >
                <i className="fa fa-download" aria-hidden />
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export const tagName = 'janus-audio';

export default AudioAuthor;
