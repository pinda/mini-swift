/*
 Copyright [2019] [BQ]
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

public protocol PromiseType {
    associatedtype Element
    
    var result: Result<Element, Swift.Error>? { get }
    
    var isPending: Bool { get }
    var isResolved: Bool { get }
    var isFulfilled: Bool { get }
    var isRejected: Bool { get }
    var value: Element? { get }
    var error: Swift.Error? { get }
    
    
    func fulfill(_ value: Element)
    func reject(_ error: Swift.Error)
}

public final class Promise<T>: PromiseType {

    public typealias Element = T
    
    public let date = Date()
    
    private let box: Box<Result<T, Swift.Error>>

    fileprivate init(box: SealedBox<Result<T, Swift.Error>>) {
        self.box = box
    }

    public class func value(_ value: T) -> Promise<T> {
        return Promise(box: SealedBox(value: Result.success(value)))
    }
    
    public class func error(_ error: Swift.Error) -> Promise<T> {
        return Promise(box: SealedBox(value: Result.failure(error)))
    }

    public init(error: Swift.Error) {
        box = SealedBox(value: Result.failure(error))
    }

    private init(_ sealant: Sealant<T>) {
        box = EmptyBox()
    }

    public init() {
        box = EmptyBox()
    }

    public class func pending() -> Promise<T> {
        return Promise<T>(.pending)
    }

    public var result: Result<T, Swift.Error>? {
        switch box.inspect() {
        case .pending:
            return nil
        case .resolved(let result):
            return result
        }
    }

    /// - Note: `fulfill` do not trigger an object reassignment,
    /// so no notifications about it can be triggered.
    public func fulfill(_ value: T) {
        self.box.seal(.success(value))
    }

    /// - Note: `reject` do not trigger an object reassignment,
    /// so no notifications about it can be triggered.
    public func reject(_ error: Swift.Error) {
        self.box.seal(.failure(error))
    }
}

public extension Promise {

    /**
     - Returns: `true` if the promise has not yet resolved.
     */
    var isPending: Bool {
        return result == nil
    }

    /**
     - Returns: `true` if the promise has resolved.
     */
    var isResolved: Bool {
        return !isPending
    }

    /**
     - Returns: `true` if the promise was fulfilled.
     */
    var isFulfilled: Bool {
        return value != nil
    }

    /**
     - Returns: `true` if the promise was rejected.
     */
    var isRejected: Bool {
        return error != nil
    }

    /**
     - Returns: The value with which this promise was fulfilled or `nil` if this promise is pending or rejected.
     */
    var value: T? {
        switch result {
        case .none:
            return nil
        case .some(.success(let value)):
            return value
        case .some(.failure):
            return nil
        }
    }

    /**
     - Returns: The error with which this promise was rejected or `nil` if this promise is pending or fulfilled.
     */
    var error: Swift.Error? {
        switch result {
        case .none:
            return nil
        case .some(.success):
            return nil
        case .some(.failure(let error)):
            return error
        }
    }
}

extension Promise where T == () {
    public convenience init() {
        self.init(box: SealedBox<Result<(), Error>>(value: .success(())))
    }
}

extension Promise: Equatable where T == () {

    public static func == (lhs: Promise<T>, rhs: Promise<T>) -> Bool {
        return true
    }
}

extension Promise where T: Equatable {

    public static func == (lhs: Promise<T>, rhs: Promise<T>) -> Bool {
        guard lhs.value == rhs.value else { return false }
        guard lhs.isResolved == rhs.isResolved else { return false }
        guard lhs.isRejected == rhs.isRejected else { return false }
        guard lhs.isPending == rhs.isPending else { return false }
        if
            let result1 = lhs.result,
            let result2 = rhs.result {
            if
                case .failure = result1,
                case .failure = result2 {
                return true
            }
            guard
                case .success(let value1) = result1,
                case .success(let value2) = result2 else { return false }
            guard value1 == value2 else { return false }
        }
        return true
    }
}
