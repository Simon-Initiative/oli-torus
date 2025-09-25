import React from 'react';
import { render } from '@testing-library/react';
import { YoutubePlayer } from '../../src/components/youtube_player/YoutubePlayer';
import * as ContentModel from '../../src/data/content/model/elements/types';

jest.mock('react-youtube', () => {
  const MockYouTube = ({ opts }: any) => {
    return <div data-testid="mock-youtube" data-opts={JSON.stringify(opts)} />;
  };
  MockYouTube.displayName = 'MockYouTube';
  return MockYouTube;
});

describe('<YoutubePlayer />', () => {
  const baseVideo: ContentModel.YouTube = {
    type: 'youtube',
    src: 'my-video-id',
    id: 'vid1',
    children: [{ text: '' }],
  };

  it('should set rel=0 in playerVars in delivery mode', () => {
    const { getByTestId } = render(
      <YoutubePlayer video={baseVideo} authorMode={false} pageAttemptGuid="abc" />,
    );
    const opts = JSON.parse(getByTestId('mock-youtube').getAttribute('data-opts')!);
    expect(opts.playerVars.rel).toBe(0);
  });

  it('should set rel=0 in playerVars in author mode', () => {
    const { getByTestId } = render(
      <YoutubePlayer video={baseVideo} authorMode={true} pageAttemptGuid="abc" />,
    );
    const opts = JSON.parse(getByTestId('mock-youtube').getAttribute('data-opts')!);
    expect(opts.playerVars.rel).toBe(0);
  });
});
