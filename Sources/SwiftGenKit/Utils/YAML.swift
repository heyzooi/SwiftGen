//
//  YAML.swift
//  SwiftGenKit
//
//  Created by David Jennes on 30/07/2018.
//  Copyright © 2018 AliSoftware. All rights reserved.
//
import Foundation
import PathKit
import Yams

public enum YAML {
  /// Read the contents of a YAML file located at the given path (only the first document).
  ///
  /// - parameter path: The path to the YAML file
  /// - returns: The decoded document
  public static func read(path: Path, env: [String: String] = [:]) throws -> Any? {
    let contents: String = try path.read()
    return try decode(string: contents, env: env)
  }

  /// Decode the contents of YAML string (only the first document).
  ///
  /// - parameter string: The YAML string
  /// - returns: The decoded document
  public static func decode(string: String, env: [String: String] = [:]) throws -> Any? {
    return try Yams.load(yaml: string, .default, Constructor.swiftgenContructor(env: env))
  }

  /// Encode the given object to YAML and write it to the given path
  ///
  /// - parameter object: The object to encode
  /// - parameter path: The path to the output file
  public static func write(object: Any, to path: Path) throws {
    let string = try encode(object: object)
    try path.write(string)
  }

  /// Encode the given object to YAML and return it as a string
  ///
  /// - parameter object: The object to encode
  /// - returns: The encoded YAML string
  public static func encode(object: Any) throws -> String {
    let node = try represent(object: object)
    return try Yams.serialize(node: node)
  }

  private static func represent(object: Any) throws -> Node {
    switch object {
    case let string as String:
      return Node(string, .implicit, .doubleQuoted)
    case let array as [Any]:
      return Node(try array.map(represent), Tag(.seq))
    case let dictionary as [String: Any]:
      let pairs = try dictionary.map { (Node($0.key), try represent(object: $0.value)) }
      return Node(pairs.sorted { $0.0 < $1.0 }, Tag(.map))
    case let representable as NodeRepresentable:
      return try representable.represented()
    default:
      throw YamlError.representer(problem: "Failed to represent \(object) as a Yams.Node")
    }
  }
}

// Copied from /Source/SwiftLintFramework/Models/YamlParser.swift
// of https://github.com/realm/SwiftLint/blob/d1dbc31aa9269364d6d7f43d2f99c82e12ceca6f
private extension Constructor {
  static func swiftgenContructor(env: [String: String]) -> Constructor {
    return Constructor(customScalarMap(env: env))
  }

  static func customScalarMap(env: [String: String]) -> ScalarMap {
    var map = defaultScalarMap
    map[.str] = String.constructExpandingEnvVars(env: env)
    map[.bool] = Bool.constructUsingOnlyTrueAndFalse

    return map
  }
}

private extension String {
  static func constructExpandingEnvVars(env: [String: String]) -> (_ scalar: Node.Scalar) -> String? {
    return { (scalar: Node.Scalar) -> String? in
      scalar.string.expandingEnvVars(env: env)
    }
  }

  func expandingEnvVars(env: [String: String]) -> String {
    var result = self
    for (key, value) in env {
      result = result.replacingOccurrences(of: "${\(key)}", with: value)
    }

    return result
  }
}

private extension Bool {
  // swiftlint:disable:next discouraged_optional_boolean
  static func constructUsingOnlyTrueAndFalse(from scalar: Node.Scalar) -> Bool? {
    switch scalar.string.lowercased() {
    case "true":
      return true
    case "false":
      return false
    default:
      return nil
    }
  }
}
