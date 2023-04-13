import React from 'react';
import { MaxFileUploadSizeMB } from './upload';

export const VideoUploadWarning = () => (
  <div className="alert alert-info show" role="alert">
    File uploads have a {MaxFileUploadSizeMB}mb limit. We recommend uploading your video to YouTube
    and then embedding that within your lesson for most uses.
  </div>
);
