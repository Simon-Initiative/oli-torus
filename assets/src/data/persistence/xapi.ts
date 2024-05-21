
import { Ok, ServerError, makeRequest } from './common';

export type EmitEventResult = Ok | ServerError;

export type XAPIEvent = VideoPlayedEvent | VideoPausedEvent | VideoCompletedEvent | VideoSeekedEvent;

export interface VideoPausedEvent {
  type: 'video_paused';
  category: "video";
  event_type: "paused";
  page_attempt_guid: string;
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
  page_attempt_guid: string;
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
  page_attempt_guid: string;
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
  page_attempt_guid: string;
  video_url: string;
  video_title: string;
  video_seek_to: number;
  video_seek_from: number;
  content_element_id: string;
};

export function emit_delivery(
  event: XAPIEvent,
): Promise<EmitEventResult> {
  const params = {
    url: `/xapi/delivery`,
    method: 'POST',
    body: JSON.stringify({"event": event})
  };
  return makeRequest<EmitEventResult>(params);
}
