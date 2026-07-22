import ApplicationServices
import Cocoa
import NerwAction
import NerwSearchBackend
import NerwUtils

public class MenubarSearch {
    public static let shared = MenubarSearch()
    public var isEnabled = true

    private init() {}

    public static func builtinActions() -> [NerwAction] {
        return [shared.getSearchAction()]
    }

    public func getSearchAction() -> NerwAction {
        return NerwAction(
            id: "builtin.menubar.search",
            title: "Search Menubar",
            subtitle: "Search menu items of the active application",
            icon: .system("menubar.dock.rectangle"),
            triggers: ["menubar", "menu"],
            type: .args(
                placeholder: "Menubar Items",
                searcher: { [weak self] _, query, completion in
                    guard let self = self else {
                        completion([])
                        return
                    }
                    let menubarActions = self.getMenubarActions()
                    let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
                    if trimmedQuery.isEmpty {
                        completion(menubarActions)
                    } else {
                        let searchStrings = menubarActions.map { action in
                            action.title + " " + action.subtitle
                        }
                        let fuse = Fuse()
                        let safeQuery = String(trimmedQuery.prefix(100))
                        let results = fuse.searchSync(safeQuery, in: searchStrings)
                        let matched = results.filter { $0.index < menubarActions.count }.map {
                            menubarActions[$0.index]
                        }
                        completion(matched)
                    }
                },
                perform: nil
            )
        )
    }

    public func getMenubarActions() -> [NerwAction] {
        guard isEnabled else { return [] }

        // Attempt to find the true active app before Nerw was opened
        guard let app = System.shared.lastActiveApp else { return [] }

        // Skip Nerw itself if it somehow became frontmost
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return []
        }

        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var menubarRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axApp, kAXMenuBarAttribute as CFString, &menubarRef)
        guard result == .success, let menubar = menubarRef else { return [] }

        let axMenubar = menubar as! AXUIElement

        var actions: [NerwAction] = []
        var seenIds = Set<String>()

        func traverse(element: AXUIElement, path: [String], depth: Int) {
            if depth > 10 { return }  // Safety limit

            var childrenRef: CFTypeRef?
            let childResult = AXUIElementCopyAttributeValue(
                element, kAXChildrenAttribute as CFString, &childrenRef)
            guard childResult == .success, let children = childrenRef as? [AXUIElement] else {
                return
            }

            for child in children {
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
                let role = (roleRef as? String) ?? ""

                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String) ?? ""

                // Exclude Apple menu items because they are standard and not app-specific
                if path.isEmpty && title == "Apple" { continue }
                if path.contains("Services") { continue }

                let isLeaf = (role == kAXMenuItemRole)
                var hasSubMenu = false
                var subMenuChildrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(
                    child, kAXChildrenAttribute as CFString, &subMenuChildrenRef) == .success
                {
                    if let subChildren = subMenuChildrenRef as? [AXUIElement], !subChildren.isEmpty
                    {
                        hasSubMenu = true
                    }
                }

                if isLeaf && !hasSubMenu {
                    if !title.isEmpty {
                        var newPath = path
                        newPath.append(title)
                        let actionPath = newPath.joined(separator: " > ")

                        let targetElement = child
                        let performBlock: (NerwAction) -> Void = { _ in
                            app.activate(options: .activateIgnoringOtherApps)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                AXUIElementPerformAction(targetElement, kAXPressAction as CFString)
                            }
                        }

                        let triggerTokens = title.lowercased().split(separator: " ").map(
                            String.init)

                        let id =
                            "nerw.menubar.\(app.bundleIdentifier ?? "app").\(actionPath.lowercased().replacingOccurrences(of: " ", with: "_"))"

                        if !seenIds.contains(id) {
                            seenIds.insert(id)

                            let finalIcon: NerwAction.IconType =
                                app.icon != nil
                                ? .image(app.icon!) : .system("menubar.dock.rectangle")

                            actions.append(
                                NerwAction(
                                    id: id,
                                    title: title,
                                    subtitle: "\(app.localizedName ?? "App") • Menu: \(actionPath)",
                                    icon: finalIcon,
                                    category: nil,
                                    triggers: triggerTokens,
                                    type: .instant(perform: performBlock)
                                ))
                        }
                    }
                } else {
                    var newPath = path
                    if (role == kAXMenuBarItemRole || role == kAXMenuItemRole) && !title.isEmpty {
                        newPath.append(title)
                    }
                    traverse(element: child, path: newPath, depth: depth + 1)
                }
            }
        }

        traverse(element: axMenubar, path: [], depth: 0)
        return actions
    }
}
