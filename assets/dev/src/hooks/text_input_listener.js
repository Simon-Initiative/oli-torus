export const TextInputListener = {
    mounted() {
        const change_event = this.el.getAttribute('phx-value-change') || 'change';
        this.el.addEventListener('input', (e) => {
            this.pushEvent(change_event, { id: e.target.id, value: e.target.value });
        });
    },
};
//# sourceMappingURL=text_input_listener.js.map