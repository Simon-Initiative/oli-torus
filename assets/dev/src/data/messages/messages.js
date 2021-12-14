import guid from 'utils/guid';
export var Severity;
(function (Severity) {
    Severity["Error"] = "Error";
    Severity["Warning"] = "Warning";
    Severity["Information"] = "Information";
    Severity["Task"] = "Task";
})(Severity || (Severity = {}));
export var Priority;
(function (Priority) {
    Priority[Priority["Lowest"] = 0] = "Lowest";
    Priority[Priority["Low"] = 1] = "Low";
    Priority[Priority["Medium"] = 2] = "Medium";
    Priority[Priority["High"] = 3] = "High";
    Priority[Priority["Highest"] = 4] = "Highest";
})(Priority || (Priority = {}));
export const createMessage = (params = {}) => ({
    guid: params.guid || guid(),
    severity: params.severity || Severity.Error,
    priority: params.priority || Priority.Medium,
    content: params.content || 'Default message',
    actions: params.actions || [],
    canUserDismiss: params.canUserDismiss || false,
});
//# sourceMappingURL=messages.js.map