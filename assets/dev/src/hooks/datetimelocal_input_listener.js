export const DateTimeLocalInputListener = {
    mounted() {
        const change_event = this.el.getAttribute('phx-value-change') || 'change';
        this.el.querySelector('input').addEventListener('change', (e) => {
            this.pushEvent(change_event, { id: e.target.id, value: e.target.value });
        });
    },
};
//# sourceMappingURL=datetimelocal_input_listener.js.map