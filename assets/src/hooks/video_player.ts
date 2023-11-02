export const VideoPlayer = {
  mounted() {
    const play_button = document.getElementById(this.el.id);
    const video = document.getElementById('video_' + this.el.id) as HTMLVideoElement;

    play_button?.addEventListener('click', () => {
      video.classList.remove('hidden');
      video.requestFullscreen();
      video.play();
    });

    video?.addEventListener('fullscreenchange', () => {
      if (!document.fullscreenElement) {
        video.pause();
        video.classList.add('hidden');
        video.currentTime = 0;
      }
    });
  },
};
