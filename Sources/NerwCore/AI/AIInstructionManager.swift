import Foundation

public class AIInstructionManager {
    public static let shared = AIInstructionManager()

    private init() {}

    public func buildSystemPrompt(basePrompt: String, actionIntents: Set<ActionIntent>) -> String {
        var instructions = """
            To show that you are thinking, wrap your thoughts in <think>...</think>.
            To perform an action, output an <action>JSON_PAYLOAD</action>.
            Supported actions:
            - memory: <action>{ "type": "memory", "action": "save", "content": "prefers dark mode", "importance": 8 }</action>
            """

        if actionIntents.contains(.timer) {
            instructions +=
                "\n- timer: <action>{ \"type\": \"timer\", \"duration\": 60, \"label\": \"Boil eggs\" }</action>"
        }
        if actionIntents.contains(.reminder) {
            instructions +=
                "\n- reminder (without schedule): <action>{ \"type\": \"reminder\", \"title\": \"Buy milk\" }</action>\n- reminder (with schedule): <action>{ \"type\": \"reminder\", \"title\": \"Buy milk\", \"schedule\": \"2026-06-22T10:00:00Z\" }</action> (Use only when a scheduled reminder is needed)"
        }
        if actionIntents.contains(.calendar) {
            instructions +=
                "\n- calendar: <action>{ \"type\": \"calendar\", \"title\": \"Meeting\", \"date\": \"2026-06-22T10:00:00Z\" }</action>"
        }
        if actionIntents.contains(.note) {
            instructions +=
                "\n- note: <action>{ \"type\": \"note\", \"operation\": \"append\", \"filename\": \"todo.md\", \"content\": \"- Buy milk\" }</action> (operations: create, append, overwrite)"
        }
        if actionIntents.contains(.menubar) {
            instructions +=
                "\n- menubar: <action>{ \"type\": \"menubar\", \"path\": \"File > Save\" }</action>"
        }
        if actionIntents.contains(.email) {
            instructions +=
                "\n- email: <action>{ \"type\": \"email\", \"subject\": \"Hello\", \"body\": \"Message\" }</action>"
        }

        instructions += """

            Do not output memory action unless User specify any personal information or preferences.
            Do NOT output action tags for things you cannot do.
            CRITICAL INSTRUCTION: If file contents or contexts are provided to you in the prompt (e.g. [Notes File Contents]), you MUST treat it as directly accessible. Do NOT tell the user you cannot read files or view content. Use the provided context to answer.
            """

        if !actionIntents.isEmpty {
            let actionsList = actionIntents.map { $0.rawValue }.joined(separator: ", ")
            instructions +=
                "\n\nCRITICAL: The user has requested a specific action (\(actionsList)). You MUST strictly output the JSON payload for the requested action. Reduce all creativity and conversational fluff. Write a brief sentence confirming what the action is and say it as if you performed it."
        }

        if basePrompt.isEmpty {
            return instructions
        } else {
            return basePrompt + "\n\n" + instructions
        }
    }

    public func resolveContext(for userMessage: String) async -> InjectedContext {
        let classification = IntentClassifier.shared.classify(userMessage)
        return await ContextInjectionManager.shared.fetchAllContext(
            for: Array(classification.contextIntents))
    }
}
