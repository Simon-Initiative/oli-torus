import React, { useCallback, useState } from 'react';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { onEnterApply } from 'components/editing/elements/common/settings/Settings';
import { UrlOrUpload } from 'components/media/UrlOrUpload';
import { SELECTION_TYPES } from 'components/media/manager/MediaManager';
import { Modal, ModalSize } from 'components/modal/Modal';
import * as ContentModel from 'data/content/model/elements/types';
import {
  LinkablePages,
  internalLinkPrefix,
  isInternalLink,
  normalizeHref,
  toInternalLink,
} from 'data/content/model/elements/utils';
import * as Persistence from 'data/persistence/resource';
import { configureStore } from 'state/store';
import { MediaItem } from 'types/media';

const store = configureStore();

interface ModalProps {
  onDone: (x: any) => void;
  onCancel: () => void;
  model: ContentModel.Hyperlink;
  commandContext: CommandContext;
  projectSlug: string;
}

function getCurrentSlugFromLink(href: string) {
  return href.startsWith('/course/link/') ? href.slice(href.lastIndexOf('/') + 1) : undefined;
}

const getHyperlinkType = (
  linkType: undefined | ContentModel.HyperlinkType,
  href: string,
): ContentModel.HyperlinkType => {
  return linkType || (isInternalLink(href) ? 'page' : 'url');
};

export const LinkModal = ({ onDone, onCancel, model, commandContext, projectSlug }: ModalProps) => {
  const [href, setHref] = useState(model.href);
  const [source, setSource] = useState<ContentModel.HyperlinkType>(
    getHyperlinkType(model.linkType, model.href),
  );

  const [pages, setPages] = useState<LinkablePages>({ type: 'Uninitialized' });
  const [selectedPage, setSelectedPage] = useState<null | Persistence.Page>(null);

  // Email mode: internal course-page links only, sourced from the passed-in page list
  // (no author-only fetch, no external/media options). See CommandContext.linkContext.
  const emailMode = commandContext.linkContext?.mode === 'email';
  const emailPages = commandContext.linkContext?.pages ?? [];
  const [emailSelectedSlug, setEmailSelectedSlug] = useState<string | null>(() => {
    if (!emailMode) return null;
    const currentSlug = isInternalLink(model.href)
      ? model.href.slice(model.href.lastIndexOf('/') + 1)
      : undefined;
    const found = emailPages.find((p) => p.slug === currentSlug);
    return (found ?? emailPages[0])?.slug ?? null;
  });

  const commitValue = useCallback(() => {
    if (emailMode) {
      if (!emailSelectedSlug) return;
      onDone({ linkType: 'page', href: `${internalLinkPrefix}/${emailSelectedSlug}` });
      return;
    }
    const hrefWithProtocol = source === 'page' ? href : normalizeHref(href);
    onDone({ linkType: source, href: hrefWithProtocol });
  }, [emailMode, emailSelectedSlug, href, onDone, source]);
  React.useEffect(() => {
    // Email mode sources pages from linkContext; skip the author-only pages fetch entirely.
    if (emailMode) return;
    setPages({ type: 'Waiting' });

    Persistence.pages(commandContext.projectSlug, getCurrentSlugFromLink(model.href)).then(
      (result) => {
        if (result.type === 'success') {
          const sortedPages = [...result.pages].sort((a, b) => {
            const aIndex = a.numbering_index ?? 0;
            const bIndex = b.numbering_index ?? 0;
            return aIndex - bIndex;
          });
          Maybe.maybe(sortedPages.find((p) => toInternalLink(p) === href)).caseOf({
            just: (found) => setSelectedPage(found),
            nothing: () => setSelectedPage(sortedPages[0]),
          });
        }

        setPages(result);
      },
      () => {
        setPages({
          type: 'ServerError',
          result: 'failure',
          status: 'error',
          statusText: 'Network Error',
          message: 'Failed to load pages',
        });
      },
    );
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [commandContext.projectSlug, emailMode]);

  const renderLoading = () => <div>Loading...</div>;
  const renderFailed = () => <div>Failed to initialize. Close this window and try again.</div>;

  const renderEmailPicker = () => {
    if (emailPages.length === 0) {
      return <div>No course pages are available to link to.</div>;
    }

    // Pages can share a title; append the (unique) slug only for the duplicated ones so the
    // distinct pages stay distinguishable without adding noise to unique titles.
    // Map (not a plain object) so titles like "__proto__"/"toString"/"constructor" can't
    // collide with inherited object properties and corrupt the counts.
    const titleCounts = emailPages.reduce(
      (acc, p) => acc.set(p.title, (acc.get(p.title) ?? 0) + 1),
      new Map<string, number>(),
    );
    const pageLabel = (p: { title: string; slug: string }) =>
      (titleCounts.get(p.title) ?? 0) > 1 ? `${p.title} (${p.slug})` : p.title;

    return (
      <div className="settings-editor">
        <label className="form-label" htmlFor="email-link-page-select">
          Link to a page in the course
        </label>
        <select
          id="email-link-page-select"
          data-modal-autofocus
          className="form-control"
          value={emailSelectedSlug ?? ''}
          onChange={(e) => setEmailSelectedSlug(e.target.value)}
          style={{ width: '100%' }}
        >
          {emailPages.map((p) => (
            <option key={p.id} value={p.slug}>
              {pageLabel(p)}
            </option>
          ))}
        </select>
      </div>
    );
  };

  const renderSuccess = (pages: Persistence.PagesReceived) => {
    const onChangeSource = (e: React.ChangeEvent<HTMLInputElement>) => {
      const value = e.target.value as ContentModel.HyperlinkType;
      switch (value) {
        case 'page':
          if (pages.pages.length > 0) {
            const sortedPages = [...pages.pages].sort((a, b) => {
              const aIndex = a.numbering_index ?? 0;
              const bIndex = b.numbering_index ?? 0;
              return aIndex - bIndex;
            });
            setHref(toInternalLink(sortedPages[0]));
          }
          break;
        case 'url':
        case 'media_library':
          setHref('');
          break;
      }

      setSource(value);
    };

    const linkOptions = (
      <div className="d-flex flex-column">
        <div className="form-check">
          <input
            className="form-check-input mr-1"
            defaultChecked={source === 'page'}
            onChange={onChangeSource}
            type="radio"
            name="inlineRadioOptions"
            id="inlineRadio1"
            value="page"
          />
          <label className="form-check-label" htmlFor="inlineRadio1">
            Link to Page in the Course
          </label>
        </div>
        <div className="form-check">
          <input
            className="form-check-input mr-1"
            defaultChecked={source === 'url'}
            onChange={onChangeSource}
            type="radio"
            name="inlineRadioOptions"
            id="inlineRadio2"
            value="url"
          />
          <label className="form-check-label" htmlFor="inlineRadio2">
            Link to External Web Page
          </label>
        </div>
        <div className="form-check">
          <input
            className="form-check-input mr-1"
            defaultChecked={source === 'media_library'}
            onChange={onChangeSource}
            type="radio"
            name="inlineRadioOptions"
            id="inlineRadio3"
            value="media_library"
          />
          <label className="form-check-label" htmlFor="inlineRadio3">
            Link to media library item
          </label>
        </div>
      </div>
    );

    return (
      <div className="settings-editor">
        HREF: {href}
        <div className="mb-2 d-flex justify-content-between">{linkOptions}</div>
        {source === 'page' && (
          <PageSelect
            href={href}
            setHref={setHref}
            selectedPage={selectedPage}
            setSelectedPage={setSelectedPage}
            pages={pages}
          />
        )}
        {source === 'url' && <HrefInput href={href} setHref={setHref} commitValue={commitValue} />}
        {source === 'media_library' && (
          <MediaLibraryInput
            projectSlug={projectSlug}
            href={href}
            setHref={setHref}
            commitValue={commitValue}
          />
        )}
      </div>
    );
  };

  let renderedState = renderLoading();
  if (emailMode) {
    renderedState = renderEmailPicker();
  } else if (pages.type === 'success') {
    renderedState = renderSuccess(pages);
  } else if (pages.type === 'ServerError') {
    renderedState = renderFailed();
  }

  return (
    <Modal
      title={emailMode ? 'Insert link to course page' : ''}
      size={ModalSize.LARGE}
      okLabel="Save"
      cancelLabel="Cancel"
      onCancel={onCancel}
      onOk={commitValue}
      disableOk={emailMode && !emailPages.some((p) => p.slug === emailSelectedSlug)}
    >
      {renderedState}
    </Modal>
  );
};

const PageOption = (p: Persistence.Page) => (
  <option key={p.id} value={toInternalLink(p)}>
    {p.title}
  </option>
);

const PageSelect: React.FC<{
  href: string;
  setHref: (x: string) => void;
  selectedPage: Persistence.Page | null;
  setSelectedPage: (x: Persistence.Page) => void;
  pages: Persistence.PagesReceived;
}> = ({ href, setHref, selectedPage, setSelectedPage, pages }) => {
  const sortedPages = [...pages.pages].sort((a, b) => {
    const aIndex = a.numbering_index ?? 0;
    const bIndex = b.numbering_index ?? 0;
    return aIndex - bIndex;
  });

  return (
    <form className="form-inline">
      <label className="sr-only">Link</label>

      <select
        className="form-control mr-2"
        value={toInternalLink(selectedPage)}
        onChange={(e) => {
          const href = e.target.value;
          setHref(href);
          const item = sortedPages.find((p) => toInternalLink(p) === href);
          if (item) setSelectedPage(item);
        }}
        style={{ minWidth: '300px' }}
      >
        {sortedPages.map(PageOption)}
      </select>
    </form>
  );
};

const HrefInput: React.FC<{
  href: string;
  setHref: (x: string) => void;
  commitValue: () => void;
}> = ({ href, setHref, commitValue }) => (
  <form className="form-inline">
    <label className="sr-only">Link</label>

    <input
      onMouseDown={(e) => e.currentTarget.focus()}
      type="text"
      defaultValue={href}
      placeholder="www.google.com"
      onChange={(e) => setHref(e.target.value)}
      onKeyPress={(e: any) => onEnterApply(e, commitValue)}
      className={'form-control mr-sm-2'}
      style={{ display: 'inline ', width: '300px' }}
    />
  </form>
);

const MediaLibraryInput: React.FC<{
  href: string;
  projectSlug: string;
  setHref: (x: string) => void;
  commitValue: () => void;
}> = ({ href, setHref, projectSlug, commitValue }) => {
  const onMediaChange = useCallback(
    (items: MediaItem[]) => {
      if (items.length > 0) {
        setHref(items[0].url);
      } else {
        setHref('');
      }
    },
    [setHref],
  );
  return (
    <Provider store={store}>
      <UrlOrUpload
        onUrlChange={setHref}
        onMediaSelectionChange={onMediaChange}
        projectSlug={projectSlug}
        mimeFilter={undefined}
        selectionType={SELECTION_TYPES.SINGLE}
        initialSelectionPaths={href ? [href] : []}
        externalUrlAllowed={false}
      ></UrlOrUpload>
    </Provider>
  );
};
