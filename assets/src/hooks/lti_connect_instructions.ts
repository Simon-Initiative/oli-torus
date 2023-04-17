export const LtiConnectInstructions = {
  mounted() {
    const canvasDeveloperInput = document.getElementById(
      'canvas_developer_key_url',
    ) as HTMLInputElement;
    const canvasDeveloperInputValue = canvasDeveloperInput.value;

    const courseNavigationCheckbox = document.getElementById(
      'course_navigation_default',
    ) as HTMLInputElement;

    courseNavigationCheckbox.addEventListener('change', () => {
      if (courseNavigationCheckbox?.checked) {
        canvasDeveloperInput.value =
          canvasDeveloperInputValue + '?course_navigation_default=disabled';
      } else {
        canvasDeveloperInput.value = canvasDeveloperInputValue;
      }
    });
  },
};
