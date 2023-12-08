export const VideoPlayer = {
  mounted() {
    const video = document.getElementById('student_learn_video') as HTMLVideoElement;

    window.addEventListener('phx:play_video', (e) => {
      video.classList.remove('hidden');
      video.requestFullscreen();
      video.setAttribute('src', (e as CustomEvent).detail.video_url);
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
