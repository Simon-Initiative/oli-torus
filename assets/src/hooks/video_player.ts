export const VideoPlayer = {
  mounted() {
    const cloudVideo = document.getElementById('cloud_video') as HTMLVideoElement;
    const youtubeIframe = document.getElementById('youtube_video') as HTMLIFrameElement;
    const videoWrapper = document.getElementById('student_video_wrapper') as HTMLDivElement;

    window.addEventListener('phx:play_video', (e) => {
      const videoUrl = (e as CustomEvent).detail.video_url;

      videoWrapper.classList.remove('hidden');
      if (videoUrl.includes('youtube.com') || videoUrl.includes('youtu.be')) {
        youtubeIframe.src = this.convertToEmbedURL(videoUrl);
        youtubeIframe.requestFullscreen();
      } else {
        cloudVideo.requestFullscreen();
        cloudVideo.setAttribute('src', videoUrl);
        cloudVideo.play();
      }
    });

    /**
      The convertToEmbedURL function is designed to convert various YouTube URL formats into a standardized embeddable URL format. This is crucial for embedding YouTube videos within an iframe.

      The regular expression used below is crafted to identify and extract the video ID from different YouTube URL formats. It is versatile enough to handle standard and shortened YouTube URLs.
      Handled Formats:
      - Standard: https://www.youtube.com/watch?v=VIDEO_ID
      - Shortened: https://youtu.be/VIDEO_ID
      - Embed: https://www.youtube.com/embed/VIDEO_ID

      The expression consists of two main parts:
      - The first part (youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=) captures the various URL structures preceding the video ID.
      = The second part ([^#\&\?]*).*, which corresponds to match[2], captures the actual video ID.

      YouTube video IDs typically have a length of exactly 11 characters. This standardization is a part of YouTube's design.
      The check match[2].length == 11 is employed to ensure that the extracted string is indeed a valid YouTube video ID.
  */
    this.convertToEmbedURL = (url) => {
      const regExp = /^.*(youtu\.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
      const match = url.match(regExp);
      const videoId = match && match[2].length == 11 ? match[2] : null;
      if (videoId) {
        return `https://www.youtube.com/embed/${videoId}?autoplay=1`;
      } else {
        return url;
      }
    };

    document.addEventListener('fullscreenchange', () => {
      if (!document.fullscreenElement) {
        cloudVideo.pause();
        cloudVideo.currentTime = 0;

        youtubeIframe.src = '';

        videoWrapper.classList.add('hidden');
      }
    });
  },
};
