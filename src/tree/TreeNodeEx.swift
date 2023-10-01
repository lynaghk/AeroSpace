extension TreeNode {
    private func visit(node: TreeNode, result: inout [Window]) {
        if let node = node as? Window {
            result.append(node)
        }
        for child in node.children {
            visit(node: child, result: &result)
        }
    }
    var allLeafWindowsRecursive: [Window] {
        var result: [Window] = []
        visit(node: self, result: &result)
        return result
    }

    var ownIndexOrNil: Int? {
        guard let parent else { return nil }
        return parent.children.firstIndex(of: self)!
    }

    var parents: [TreeNode] { parent.flatMap { [$0] + $0.parents } ?? [] }
    var parentsWithSelf: [TreeNode] { parent.flatMap { [self] + $0.parentsWithSelf } ?? [self] }

    var workspace: Workspace {
        self as? Workspace ?? parent?.workspace ?? errorT("Unknown type \(Self.self)")
    }

    func allLeafWindowsRecursive(snappedTo direction: CardinalDirection) -> [Window] {
        switch kind {
        case .workspace(let workspace):
            return workspace.rootTilingContainer.allLeafWindowsRecursive(snappedTo: direction)
        case .window(let window):
            return [window]
        case .tilingContainer(let container):
            if direction.orientation == container.orientation {
                return (direction.isPositive ? container.children.last : container.children.first)?
                    .allLeafWindowsRecursive(snappedTo: direction) ?? []
            } else {
                return children.flatMap { $0.allLeafWindowsRecursive(snappedTo: direction) }
            }
        }
    }

    var anyLeafWindowRecursive: Window? {
        if let window = children.first(where: { $0 is Window }) {
            return (window as! Window)
        }
        for child in children {
            if let window = child.anyLeafWindowRecursive {
                return window
            }
        }
        return nil
    }

    // Doesn't contain at least one window
    var isEffectivelyEmpty: Bool {
        anyLeafWindowRecursive == nil
    }

    var hWeight: CGFloat {
        get { getWeight(.H) }
        set { setWeight(.H, newValue) }
    }

    var vWeight: CGFloat {
        get { getWeight(.V) }
        set { setWeight(.V, newValue) }
    }

    func getCenter() -> CGPoint? { getRect()?.center }

    /// Containers' weights must be normalized before calling this function
    func layoutRecursive(_ _point: CGPoint, width: CGFloat, height: CGFloat) {
        switch kind {
        case .workspace(let workspace):
            workspace.rootTilingContainer.layoutRecursive(_point, width: width, height: height)
        case .window(let window):
            window.setTopLeftCorner(_point)
            window.setSize(CGSize(width: width, height: height))
        case .tilingContainer(let container):
            var point = _point
            for child in container.children {
                switch container.layout {
                case .Accordion: // todo layout with accordion offset
                    child.layoutRecursive(point, width: width, height: height)
                case .List:
                    child.layoutRecursive(point, width: child.hWeight, height: child.vWeight)
                    switch container.orientation {
                    case .H:
                        point = point.copy(x: point.x + child.hWeight)
                    case .V:
                        point = point.copy(y: point.y + child.vWeight)
                    }
                }
            }
        }
    }

    var kind: TreeNodeKind {
        if let window = self as? Window {
            return .window(window)
        } else if let workspace = self as? Workspace {
            return .workspace(workspace)
        } else if let tilingContainer = self as? TilingContainer {
            return .tilingContainer(tilingContainer)
        } else {
            error("Unknown tree")
        }
    }
}