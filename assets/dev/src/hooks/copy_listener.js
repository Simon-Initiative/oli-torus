export const CopyListener = {
    mounted() {
        const clipTargetSelector = this.el.dataset['clipboardTarget'];
        const el = this.el;
        const originalHTML = this.el.innerHTML;
        this.el.addEventListener('click', (_e) => {
            var _a;
            const targetText = (_a = document.querySelector(clipTargetSelector)) === null || _a === void 0 ? void 0 : _a.value;
            navigator.clipboard.writeText(targetText).then(function () {
                el.innerHTML = 'Copied!';
                setTimeout(() => {
                    el.innerHTML = originalHTML;
                }, 5000);
            });
        });
    },
};
//# sourceMappingURL=copy_listener.js.map