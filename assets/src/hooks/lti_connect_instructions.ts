export const LtiConnectInstructions = {
  mounted() {
    const canvasDeveloperInput = <HTMLInputElement>(
      document.getElementById('canvas_developer_key_url')
    );
    const canvasDeveloperInputValue = canvasDeveloperInput.value;

    const courseNavigationCheckbox = <HTMLInputElement>(
      document.getElementById('course_navigation_default')
    );

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
