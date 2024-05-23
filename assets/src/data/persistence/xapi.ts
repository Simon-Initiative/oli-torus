
import { Ok, ServerError, makeRequest } from './common';

export type EmitEventResult = Ok | ServerError;

export type VideoKey = PageVideoKey | IntroVideoKey;
export type XAPIEvent = VideoPlayedEvent | VideoPausedEvent | VideoCompletedEvent | VideoSeekedEvent;

export type PlayedSegment = {
  start: number;
  end: number | null;
};

export const formatSegments = (segments: PlayedSegment[]) => {
  return segments.map((segment) => {
    return `${segment.start}[.]${segment.end || ''}`;
  }).join('[,]');
};

export const calculateProgress = (segments: { start: number; end: number | null }[], duration: number) => {
  let total = 0;
  segments.forEach((segment) => {
    if (segment.end) {
      total += segment.end - segment.start;
    }
  });

  return total / duration;
};

export interface PageVideoKey {
  type: 'page_video_key';
  page_attempt_guid: string;
}

export interface IntroVideoKey {
  type: 'intro_video_key';
  resource_id: number;
  section_id: number;
}

export interface VideoPausedEvent {
  type: 'video_paused';
  category: "video";
  event_type: "paused";
  video_url: string;
  video_title: string;
  video_length: number;
  video_played_segments: string;
  video_progress: number;
  video_time: number;
  content_element_id: string;
};

export interface VideoPlayedEvent {
  type: 'video_played';
  category: "video";
  event_type: "played";
  video_url: string;
  video_title: string;
  video_length: number;
  video_play_time: number;
  content_element_id: string;
};

export interface VideoCompletedEvent {
  type: 'video_completed';
  category: "video";
  event_type: "completed";
  video_url: string;
  video_title: string;
  video_length: number;
  video_played_segments: string;
  video_progress: number;
  video_time: number;
  content_element_id: string;
};

export interface VideoSeekedEvent {
  type: 'video_seeked';
  category: "video";
  event_type: "seeked";
  video_url: string;
  video_title: string;
  video_seek_to: number;
  video_seek_from: number;
  content_element_id: string;
};

export function emit_delivery(
  key: VideoKey,
  event: XAPIEvent,
): Promise<EmitEventResult> {
  const params = {
    url: `/xapi/delivery`,
    method: 'POST',
    body: JSON.stringify({"event": event, "key": key})
  };
  return makeRequest<EmitEventResult>(params);
}
