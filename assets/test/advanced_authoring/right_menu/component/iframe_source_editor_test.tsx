import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { decodeSourceConfig, encodeSourceConfig } from 'components/parts/janus-capi-iframe/schema';
import IframeSourceEditor from 'apps/authoring/components/PropertyEditor/custom/IframeSourceEditor';
import * as Persistence from 'data/persistence/resource';

describe('IframeSourceEditor', () => {
  beforeEach(() => {
    window.history.pushState({}, '', '/authoring/project/demo-course/resource/example-page');
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('defaults to external url input and updates url value', () => {
    const onChange = jest.fn();
    render(
      <IframeSourceEditor
        id="root_custom_source"
        value="https://example.com"
        onChange={onChange}
      />,
    );

    const externalCheckbox = screen.getByLabelText('External URL') as HTMLInputElement;
    expect(externalCheckbox.checked).toBe(true);

    const urlInput = screen.getByLabelText('Source URL') as HTMLInputElement;
    expect(urlInput.value).toBe('https://example.com');

    fireEvent.change(urlInput, { target: { value: 'https://example.com/updated' } });

    const lastCall = onChange.mock.calls[onChange.mock.calls.length - 1][0];
    const sourceConfig = decodeSourceConfig(lastCall);
    expect(sourceConfig.mode).toBe('url');
    expect(sourceConfig.url).toBe('https://example.com/updated');
  });

  // @ac "AC-001"
  it('switches to page mode, loads pages, and exposes dropdown-only selection', async () => {
    const onChange = jest.fn();
    jest.spyOn(Persistence, 'pages').mockResolvedValue({
      type: 'success',
      pages: [
        { id: 30, slug: 'third', title: 'Third Page', numbering_index: 3 },
        { id: 10, slug: 'first', title: 'First Page', numbering_index: 1 },
      ],
    });

    render(
      <IframeSourceEditor
        id="root_custom_source"
        value={encodeSourceConfig({
          mode: 'url',
          url: 'https://example.com',
          pageId: null,
          pageSlug: '',
        })}
        onChange={onChange}
      />,
    );

    fireEvent.click(screen.getByLabelText('Page Link'));

    await waitFor(() => expect(Persistence.pages).toHaveBeenCalledWith('demo-course'));
    await waitFor(() => expect(screen.getByLabelText('Select Page')).toBeInTheDocument());

    expect(screen.queryByLabelText('Source URL')).not.toBeInTheDocument();

    const select = screen.getByLabelText('Select Page');
    fireEvent.change(select, { target: { value: '30' } });

    const lastCall = onChange.mock.calls[onChange.mock.calls.length - 1][0];
    const sourceConfig = decodeSourceConfig(lastCall);
    expect(sourceConfig.mode).toBe('page');
    expect(sourceConfig.pageId).toBe(30);
    expect(sourceConfig.pageSlug).toBe('third');
  });

  it('shows an error state when pages cannot be loaded', async () => {
    jest.spyOn(Persistence, 'pages').mockResolvedValue({
      type: 'ServerError',
      message: 'failed',
    } as any);

    render(
      <IframeSourceEditor
        id="root_custom_source"
        value={encodeSourceConfig({ mode: 'page', url: '', pageId: null, pageSlug: '' })}
        onChange={jest.fn()}
      />,
    );

    expect(await screen.findByText('Unable to load pages')).toBeInTheDocument();
  });

  it('loads pages using project slug from workspace authoring routes', async () => {
    window.history.pushState(
      {},
      '',
      '/workspaces/course_author/demo-workspace/curriculum/example-page/edit',
    );

    jest.spyOn(Persistence, 'pages').mockResolvedValue({
      type: 'success',
      pages: [{ id: 1, slug: 'one', title: 'Page One', numbering_index: 1 }],
    });

    render(
      <IframeSourceEditor
        id="root_custom_source"
        value={encodeSourceConfig({ mode: 'page', url: '', pageId: null, pageSlug: '' })}
        onChange={jest.fn()}
      />,
    );

    await waitFor(() => expect(Persistence.pages).toHaveBeenCalledWith('demo-workspace'));
    expect(await screen.findByLabelText('Select Page')).toBeInTheDocument();
  });
});
