import React from 'react';
import { render } from '@testing-library/react';
import { WebpageEmbed } from '../../src/components/webpage/WebpageEmbed';
import { makeCommandButtonEvent } from '../../src/data/events';

describe('WebpageEmbed command targeting', () => {
  it('relays matching command messages into iframe via postMessage', () => {
    const postMessage = jest.fn();
    const { container } = render(
      <WebpageEmbed
        webpage={{
          type: 'iframe',
          id: 'dom-id',
          targetId: 'targetx',
          src: 'https://d2xvti2irp4c7t.cloudfront.net/media/test.html',
          children: [{ text: '' }],
        }}
      />,
    );

    const iframe = container.querySelector('iframe') as HTMLIFrameElement;
    Object.defineProperty(iframe, 'contentWindow', {
      value: { postMessage },
      configurable: true,
    });

    document.dispatchEvent(
      makeCommandButtonEvent({ forId: 'targetx', message: 'innerOrbitsShown.png' }),
    );

    expect(postMessage).toHaveBeenCalledTimes(1);
    expect(postMessage).toHaveBeenCalledWith(
      'innerOrbitsShown.png',
      'https://d2xvti2irp4c7t.cloudfront.net',
    );
  });

  it('ignores command messages for other targets', () => {
    const postMessage = jest.fn();
    const { container } = render(
      <WebpageEmbed
        webpage={{
          type: 'iframe',
          id: 'dom-id',
          targetId: 'targetx',
          src: 'https://d2xvti2irp4c7t.cloudfront.net/media/test.html',
          children: [{ text: '' }],
        }}
      />,
    );

    const iframe = container.querySelector('iframe') as HTMLIFrameElement;
    Object.defineProperty(iframe, 'contentWindow', {
      value: { postMessage },
      configurable: true,
    });

    document.dispatchEvent(makeCommandButtonEvent({ forId: 'other', message: 'ignored' }));

    expect(postMessage).not.toHaveBeenCalled();
  });

  it('does not render unsafe iframe src protocols', () => {
    const { container } = render(
      <WebpageEmbed
        webpage={{
          type: 'iframe',
          id: 'dom-id',
          targetId: 'targetx',
          src: 'javascript:alert(1)',
          children: [{ text: '' }],
        }}
      />,
    );

    const iframe = container.querySelector('iframe') as HTMLIFrameElement;
    expect(iframe.getAttribute('src')).toBeNull();
  });
});
