/*
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

class ConfigurationNode {
    static let separator: String = "."

    private var content: Any?

    private var children: [String: ConfigurationNode] = [:]

    init(rawValue: Any? = nil) {
        self.rawValue = rawValue
    }

    var isLeaf: Bool {
        return children.isEmpty
    }

    /// Serialize/deserialize tree at current node to/from Foundation types
    var rawValue: Any? {
        get {
            if isLeaf {
                return content
            }
            else {
                var dict: [String: Any] = [:]

                for (key, node) in children {
                    dict[key] = node.rawValue
                }

                return dict
            }
        }
        set {
            clear()

            if let dict = newValue as? [String: Any] {
                for (key, value) in dict {
                    let child = ConfigurationNode()
                    child.rawValue = value
                    children[key] = child
                }
            }
            else {
                content = newValue
            }
        }
    }

    /// Shallow depth-first merge; copy class instance references instead of deep copy
    func merge(overwrite other: ConfigurationNode) {
        // if either node is leaf, no need to do anything since current node is overriding
        if !isLeaf && !other.isLeaf {
            for (key, child) in other.children {
                if let myChild = children[key] {
                    // recursively merge/overwrite
                    myChild.merge(overwrite: child)
                }
                else {
                    // no entry for key exists in self; add it
                    children[key] = child
                }
            }
        }
    }

    /// index may be hierarchical
    subscript(index: String) -> ConfigurationNode? {
        get {
            // check if it's a hierarchical index
            if let range = index.range(of: ConfigurationNode.separator) {
                let firstKey = index.substring(to: range.lowerBound)
                let restOfKeys = index.substring(from: range.upperBound)

                return children[firstKey]?[restOfKeys]
            }
            else {
                return children[index]
            }
        }
        set {
            // check if it's a hierarchical index
            if let range = index.range(of: ConfigurationNode.separator) {
                let firstKey = index.substring(to: range.lowerBound)
                let restOfKeys = index.substring(from: range.upperBound)

                // check if child node at first key exists
                if let child = children[firstKey] {
                    child[restOfKeys] = newValue
                }
                else {
                    // child node doesn't exist
                    // create one
                    let child = ConfigurationNode()

                    // insert newValue by recursion
                    child[restOfKeys] = newValue

                    // append to children
                    children[firstKey] = child
                }
            }
            else {
                // index is same index
                // update node reference in children
                children[index] = newValue
            }
        }
    }

    private func clear() {
        content = nil
        children.removeAll()
    }
}
