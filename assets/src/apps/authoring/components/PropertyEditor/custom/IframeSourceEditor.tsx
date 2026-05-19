import React, { useEffect, useMemo, useState } from 'react';
import {
  IframeSourceEditorConfig,
  decodeSourceConfig,
  encodeSourceConfig,
} from 'components/parts/janus-capi-iframe/schema';
import * as Persistence from 'data/persistence/resource';

interface IframeSourceEditorProps {
  id: string;
  label?: string;
  value?: string;
  onChange: (value: string) => void;
  onBlur?: (id: string, value: string) => void;
  onFocus?: () => void;
}

type PagesState =
  | { type: 'idle' | 'loading' | 'error' }
  | { type: 'success'; pages: Persistence.Page[] };

const labels = {
  source: 'Source',
  pageLink: 'Page Link',
  externalUrl: 'External URL',
  pageSelect: 'Select Page',
  urlInput: 'Source URL',
  loadingPages: 'Loading pages...',
  pagesError: 'Unable to load pages',
  noPages: 'No pages available',
};

const inferProjectSlug = (): string => {
  if (typeof window === 'undefined') {
    return '';
  }

  const path = window.location?.pathname || '';
  const pathnamePatterns = [
    /\/workspaces\/course_author\/([^/]+)/,
    /\/authoring\/project\/([^/]+)/,
    /\/project\/([^/]+)/,
  ];
  for (const pattern of pathnamePatterns) {
    const match = path.match(pattern);
    if (match?.[1]) {
      return decodeURIComponent(match[1]);
    }
  }

  const bodyProjectSlug = document.body?.getAttribute('data-project-slug');
  if (bodyProjectSlug) {
    return bodyProjectSlug;
  }

  const projectSlugMeta = document.querySelector('meta[name="project-slug"]');
  return projectSlugMeta?.getAttribute('content') || '';
};

const sortPages = (pages: Persistence.Page[]) =>
  [...pages].sort((a, b) => (a.numbering_index ?? 0) - (b.numbering_index ?? 0));

const IframeSourceEditor: React.FC<IframeSourceEditorProps> = ({
  id,
  label,
  value,
  onChange,
  onFocus,
}) => {
  const [sourceConfig, setSourceConfig] = useState<IframeSourceEditorConfig>(() =>
    decodeSourceConfig(value),
  );
  const [pagesState, setPagesState] = useState<PagesState>({ type: 'idle' });

  const projectSlug = useMemo(() => inferProjectSlug(), []);

  useEffect(() => {
    setSourceConfig(decodeSourceConfig(value));
  }, [value]);

  useEffect(() => {
    if (sourceConfig.mode !== 'page') {
      return;
    }

    if (!projectSlug) {
      setPagesState({ type: 'error' });
      return;
    }

    setPagesState({ type: 'loading' });
    Persistence.pages(projectSlug)
      .then((result) => {
        if (result.type === 'success') {
          setPagesState({ type: 'success', pages: sortPages(result.pages) });
        } else {
          setPagesState({ type: 'error' });
        }
      })
      .catch(() => setPagesState({ type: 'error' }));
  }, [projectSlug, sourceConfig.mode]);

  const commit = (next: IframeSourceEditorConfig) => {
    setSourceConfig(next);
    onChange(encodeSourceConfig(next));
  };

  useEffect(() => {
    if (sourceConfig.mode !== 'page' || pagesState.type !== 'success') {
      return;
    }

    const selected = pagesState.pages.find((page) => page.id === sourceConfig.pageId);
    if (selected && sourceConfig.pageSlug === selected.slug) {
      return;
    }

    if (sourceConfig.pageSlug) {
      const bySlug = pagesState.pages.find((page) => page.slug === sourceConfig.pageSlug);
      if (bySlug) {
        if (bySlug.id !== sourceConfig.pageId) {
          commit({ ...sourceConfig, pageId: bySlug.id });
        }
        return;
      }
    }

    const [firstPage] = pagesState.pages;
    if (!firstPage) {
      return;
    }

    commit({
      ...sourceConfig,
      pageId: firstPage.id,
      pageSlug: firstPage.slug,
    });
  }, [pagesState, sourceConfig]);

  const sourceLabel = label || labels.source;
  const pageChecked = sourceConfig.mode === 'page';
  const urlChecked = sourceConfig.mode === 'url';
  const checkedPageValue = sourceConfig.pageId ?? '';

  return (
    <div className="d-flex flex-column">
      <span className="form-label">{sourceLabel}</span>
      <div className="d-flex flex-column mb-2" role="group" aria-label={sourceLabel}>
        <div className="form-check">
          <input
            id={`${id}-page`}
            type="checkbox"
            className="form-check-input"
            checked={pageChecked}
            aria-label={labels.pageLink}
            onChange={(event) => {
              if (event.target.checked) {
                commit({ ...sourceConfig, mode: 'page' });
              }
            }}
          />
          <label className="form-check-label" htmlFor={`${id}-page`}>
            {labels.pageLink}
          </label>
        </div>
        <div className="form-check">
          <input
            id={`${id}-url`}
            type="checkbox"
            className="form-check-input"
            checked={urlChecked}
            aria-label={labels.externalUrl}
            onChange={(event) => {
              if (event.target.checked) {
                commit({ ...sourceConfig, mode: 'url' });
              }
            }}
          />
          <label className="form-check-label" htmlFor={`${id}-url`}>
            {labels.externalUrl}
          </label>
        </div>
      </div>

      {sourceConfig.mode === 'url' && (
        <div>
          <label className="sr-only" htmlFor={`${id}-url-input`}>
            {labels.urlInput}
          </label>
          <input
            id={`${id}-url-input`}
            type="text"
            className="form-control"
            value={sourceConfig.url}
            placeholder="https://example.com"
            onFocus={onFocus}
            aria-label={labels.urlInput}
            onChange={(event) =>
              commit({
                ...sourceConfig,
                url: event.target.value,
              })
            }
          />
        </div>
      )}

      {sourceConfig.mode === 'page' && (
        <div>
          <label className="sr-only" htmlFor={`${id}-page-select`}>
            {labels.pageSelect}
          </label>

          {pagesState.type === 'loading' && <div>{labels.loadingPages}</div>}
          {pagesState.type === 'error' && <div className="text-danger">{labels.pagesError}</div>}
          {pagesState.type === 'success' && pagesState.pages.length === 0 && (
            <div>{labels.noPages}</div>
          )}
          {pagesState.type === 'success' && pagesState.pages.length > 0 && (
            <select
              id={`${id}-page-select`}
              className="form-control"
              aria-label={labels.pageSelect}
              value={checkedPageValue}
              onFocus={onFocus}
              onChange={(event) => {
                const pageId = Number(event.target.value);
                const selectedPage = pagesState.pages.find((page) => page.id === pageId);
                if (!selectedPage) {
                  return;
                }
                commit({
                  ...sourceConfig,
                  pageId: selectedPage.id,
                  pageSlug: selectedPage.slug,
                });
              }}
            >
              {pagesState.pages.map((page) => (
                <option key={page.id} value={page.id}>
                  {page.title}
                </option>
              ))}
            </select>
          )}
        </div>
      )}
    </div>
  );
};

export default IframeSourceEditor;
