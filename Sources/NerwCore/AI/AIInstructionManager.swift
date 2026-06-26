import Foundation

public class AIInstructionManager {
    public static let shared = AIInstructionManager()

    private init() {}

    public func buildSystemPrompt(basePrompt: String) -> String {
        let actionInstructions = """
            To show that you are thinking, wrap your thoughts in <think>...</think>.
            To perform an action, output an <action>JSON_PAYLOAD</action>.
            Supported actions:
            - timer: <action>{ "type": "timer", "duration": 60, "label": "Boil eggs" }</action>
            - reminder: <action>{ "type": "reminder", "title": "Buy milk", "date": "2026-06-22T10:00:00Z" }</action>
            - calendar: <action>{ "type": "calendar", "title": "Meeting", "date": "2026-06-22T10:00:00Z" }</action>
            - memory: <action>{ "type": "memory", "action": "save", "content": "prefers dark mode", "importance": 8 }</action>
            - note: <action>{ "type": "note", "operation": "append", "filename": "todo.md", "content": "- Buy milk" }</action> (operations: create, append, overwrite)
            - menubar: <action>{ "type": "menubar", "path": "File > Save" }</action>
            - email: <action>{ "type": "email", "subject": "Hello", "body": "Message" }</action>
            Do not output memory action unless User specify any personal information or preferences.
            Do NOT output action tags for things you cannot do.
            CRITICAL INSTRUCTION: If file contents or contexts are provided to you in the prompt (e.g. [Notes File Contents]), you MUST treat it as directly accessible. Do NOT tell the user you cannot read files or view content. Use the provided context to answer.
            """

        if basePrompt.isEmpty {
            return actionInstructions
        } else {
            return basePrompt + "\n\n" + actionInstructions
        }
    }

    public func resolveContext(for userMessage: String) async -> InjectedContext {
        let classification = IntentClassifier.shared.classify(userMessage)
        return await ContextInjectionManager.shared.fetchAllContext(
            for: Array(classification.contextIntents))
    }
}
