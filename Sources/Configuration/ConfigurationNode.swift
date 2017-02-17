/*
 * Copyright IBM Corporation 2017
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

enum ConfigurationNode {
    static let separator = ":"

    case any(Any)
    case array([ConfigurationNode])
    case dictionary([String: ConfigurationNode])

    init(_ rawValue: Any) {
        self = .dictionary([:])
        self.rawValue = rawValue
    }

    var rawValue: Any {
        get {
            switch self {
            case .any(let nodeAny):
                return nodeAny
            case .array(let nodeArray):
                return nodeArray.map { $0.rawValue }
            case .dictionary(let nodeDictionary):
                var dictionary: [String: Any] = [:]
                nodeDictionary.forEach { dictionary[$0] = $1.rawValue }
                return dictionary
            }
        }
        set {
            if let valueArray = newValue as? [Any] {
                self = .array(valueArray.map { ConfigurationNode($0) })
            }
            else if let valueDictionary = newValue as? [String: Any] {
                self = .dictionary([:])
                valueDictionary.forEach { self[$0] = ConfigurationNode($1) }
            }
            else {
                self = .any(newValue)
            }
        }
    }

    mutating func merge(overwrittenBy other: ConfigurationNode) {
        // do deep overwrite if both are dictionary types
        // otherwise, overwrite self with other
        switch (self, other) {
        case (.dictionary(var this), .dictionary(let that)):
            that.forEach { (thatKey, thatNode) in
                if var thisNode = this[thatKey] {
                    // key exists in both
                    // do merge overwrite recursively
                    thisNode.merge(overwrittenBy: thatNode)
                    this[thatKey] = thisNode
                }
                else {
                    // key does not exist in self
                    // insert it into self
                    this[thatKey] = thatNode
                }
            }

            self = .dictionary(this)
        default:
            self = other
        }
    }

    subscript(path: String) -> ConfigurationNode? {
        get {
            var node: ConfigurationNode?
            let (firstKey, restOfKeys) = path.splitKeys

            switch self {
            case .array(let nodeArray):
                if let index = Int(firstKey),
                    nodeArray.startIndex..<nodeArray.endIndex ~= index {
                    node = nodeArray[index]
                }
            case .dictionary(let nodeDictionary):
                node = nodeDictionary[firstKey]
            default:
                node = nil
            }

            if let restOfKeys = restOfKeys {
                return node?[restOfKeys]
            }
            else {
                return node
            }
        }
        set {
            guard let newNode = newValue else {
                // do nothing
                return
            }

            let (firstKey, restOfKeys) = path.splitKeys

            switch self {
            case .array(var nodeArray):
                if let index = Int(firstKey) {
                    if nodeArray.startIndex..<nodeArray.endIndex ~= index {
                        if let restOfKeys = restOfKeys {
                            nodeArray[index][restOfKeys] = newNode
                        }
                        else {
                            nodeArray[index] = newNode
                        }
                    }
                    else if nodeArray.endIndex == index {
                        var node = ConfigurationNode.dictionary([:])

                        if let restOfKeys = restOfKeys {
                            node[restOfKeys] = newNode
                        }
                        else {
                            node = newNode
                        }

                        // insert into end of array
                        nodeArray.append(node)
                    }
                }

                self = .array(nodeArray)
            case .dictionary(var nodeDictionary):
                if nodeDictionary[firstKey] == nil {
                    // no value exists for key
                    // add it to dictionary
                    nodeDictionary[firstKey] = .dictionary([:])
                }

                if let restOfKeys = restOfKeys {
                    nodeDictionary[firstKey]?[restOfKeys] = newNode
                }
                else {
                    nodeDictionary[firstKey] = newNode
                }

                self = .dictionary(nodeDictionary)
            default:
                // insert node, overwrite self
                var node = ConfigurationNode.dictionary([:])

                if let restOfKeys = restOfKeys {
                    node[restOfKeys] = newNode
                }
                else {
                    node = newNode
                }

                let nodeDictionary = [firstKey: node]
                self = .dictionary(nodeDictionary)
            }
        }
    }
}

extension String {
    var splitKeys: (String, String?) {
        guard let range = self.range(of: ConfigurationNode.separator) else {
            return (self, nil)
        }

        return (self.substring(to: range.lowerBound), self.substring(from: range.upperBound))
    }
}
