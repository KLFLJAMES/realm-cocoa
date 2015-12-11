////////////////////////////////////////////////////////////////////////////
//
// Copyright 2014 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import Realm

// MARK: MinMaxType

/// Types which can be used for min()/max().
public protocol MinMaxType {}
extension Double: MinMaxType {}
extension Float: MinMaxType {}
extension Int: MinMaxType {}
extension Int8: MinMaxType {}
extension Int16: MinMaxType {}
extension Int32: MinMaxType {}
extension Int64: MinMaxType {}
extension NSDate: MinMaxType {}

// MARK: AddableType

/// Types which can be used for average()/sum().
public protocol AddableType {}
extension Double: AddableType {}
extension Float: AddableType {}
extension Int: AddableType {}
extension Int8: AddableType {}
extension Int16: AddableType {}
extension Int32: AddableType {}
extension Int64: AddableType {}

/// :nodoc:
/// Internal class. Do not use directly.
public class ResultsBase: NSObject, NSFastEnumeration {
    internal let rlmResults: RLMResults

    /// Returns a human-readable description of the objects contained in these results.
    public override var description: String {
        let type = "Results<\(rlmResults.objectClassName)>"
        return gsub("RLMResults <0x[a-z0-9]+>", type, rlmResults.description) ?? type
    }

    // MARK: Initializers

    internal init(_ rlmResults: RLMResults) {
        self.rlmResults = rlmResults
    }

    // MARK: Fast Enumeration

    public func countByEnumeratingWithState(state: UnsafeMutablePointer<NSFastEnumerationState>, objects buffer: AutoreleasingUnsafeMutablePointer<AnyObject?>, count len: Int) -> Int {
        let enumeration: NSFastEnumeration = rlmResults // FIXME: no idea why this is needed, but doesn't compile otherwise
        return enumeration.countByEnumeratingWithState(state, objects: buffer, count: len)
    }
}

/**
`Results` is an auto-updating container type in Realm returned from object
queries.

Results can be queried with the same predicates as `List<T>` and you can chain queries to further
filter query results.

Results cannot be created directly.
*/
public final class Results<T: Object>: ResultsBase {

    /// Element type contained in this collection.
    typealias Element = T

    // MARK: Properties

    /// Returns the Realm these results are associated with.
    /// Despite returning an `Optional<Realm>` in order to conform to
    /// `RealmCollectionType`, it will always return `.Some()` since a `Results`
    /// cannot exist independently from a `Realm`.
    public var realm: Realm? { return Realm(rlmResults.realm) }

    /// Returns the number of objects in these results.
    public var count: Int { return Int(rlmResults.count) }

    // MARK: Initializers

    internal override init(_ rlmResults: RLMResults) {
        super.init(rlmResults)
    }

    // MARK: Index Retrieval

    /**
    Returns the index of the given object, or `nil` if the object is not in the results.

    :param: object The object whose index is being queried.

    :returns: The index of the given object, or `nil` if the object is not in the results.
    */
    public func indexOf(object: T) -> Int? {
        return notFoundToNil(rlmResults.indexOfObject(unsafeBitCast(object, RLMObject.self)))
    }

    /**
    Returns the index of the first object matching the given predicate,
    or `nil` if no objects match.

    :param: predicate The predicate to filter the objects.

    :returns: The index of the first matching object, or `nil` if no objects match.
    */
    public func indexOf(predicate: NSPredicate) -> Int? {
        return notFoundToNil(rlmResults.indexOfObjectWithPredicate(predicate))
    }

    /**
    Returns the index of the first object matching the given predicate,
    or `nil` if no objects match.

    :param: predicateFormat The predicate format string which can accept variable arguments.

    :returns: The index of the first matching object, or `nil` if no objects match.
    */
    public func indexOf(predicateFormat: String, _ args: CVarArgType...) -> Int? {
        return notFoundToNil(rlmResults.indexOfObjectWithPredicate(NSPredicate(format: predicateFormat, arguments: getVaList(args))))
    }

    // MARK: Object Retrieval

    /**
    Returns the object at the given `index`.

    :param: index The index.

    :returns: The object at the given `index`.
    */
    public subscript(index: Int) -> T {
        get {
            throwForNegativeIndex(index)
            return unsafeBitCast(rlmResults[UInt(index)], T.self)
        }
    }

    /// Returns the first object in the results, or `nil` if empty.
    public var first: T? { return unsafeBitCast(rlmResults.firstObject(), Optional<T>.self) }

    /// Returns the last object in the results, or `nil` if empty.
    public var last: T? { return unsafeBitCast(rlmResults.lastObject(), Optional<T>.self) }

    // MARK: KVC

    /**
    Returns an Array containing the results of invoking `valueForKey(_:)` using key on each of the collection's objects.

    :param: key The name of the property.

    :returns: Array containing the results of invoking `valueForKey(_:)` using key on each of the collection's objects.
    */
    public override func valueForKey(key: String) -> AnyObject? {
        return rlmResults.valueForKey(key)
    }

    /**
    Invokes `setValue(_:forKey:)` on each of the collection's objects using the specified value and key.

    :warning: This method can only be called during a write transaction.

    :param: value The object value.
    :param: key   The name of the property.
    */
    public override func setValue(value: AnyObject?, forKey key: String) {
        return rlmResults.setValue(value, forKey: key)
    }

    // MARK: Filtering

    /**
    Filters the results to the objects that match the given predicate.

    :param: predicateFormat The predicate format string which can accept variable arguments.

    :returns: Results containing objects that match the given predicate.
    */
    public func filter(predicateFormat: String, _ args: CVarArgType...) -> Results<T> {
        return Results<T>(rlmResults.objectsWithPredicate(NSPredicate(format: predicateFormat, arguments: getVaList(args))))
    }

    /**
    Filters the results to the objects that match the given predicate.

    :param: predicate The predicate to filter the objects.

    :returns: Results containing objects that match the given predicate.
    */
    public func filter(predicate: NSPredicate) -> Results<T> {
        return Results<T>(rlmResults.objectsWithPredicate(predicate))
    }

    // MARK: Sorting

    /**
    Returns `Results` with elements sorted by the given property name.

    :param: property  The property name to sort by.
    :param: ascending The direction to sort by.

    :returns: `Results` with elements sorted by the given property name.
    */
    public func sorted(property: String, ascending: Bool = true) -> Results<T> {
        return sorted([SortDescriptor(property: property, ascending: ascending)])
    }

    /**
    Returns `Results` with elements sorted by the given sort descriptors.

    :param: sortDescriptors `SortDescriptor`s to sort by.

    :returns: `Results` with elements sorted by the given sort descriptors.
    */
    public func sorted<S: SequenceType where S.Generator.Element == SortDescriptor>(sortDescriptors: S) -> Results<T> {
        return Results<T>(rlmResults.sortedResultsUsingDescriptors(map(sortDescriptors) { $0.rlmSortDescriptorValue }))
    }

    // MARK: Aggregate Operations

    /**
    Returns the minimum value of the given property.

    :warning: Only names of properties of a type conforming to the `MinMaxType` protocol can be used.

    :param: property The name of a property conforming to `MinMaxType` to look for a minimum on.

    :returns: The minimum value for the property amongst objects in the Results, or `nil` if the Results is empty.
    */
    public func min<U: MinMaxType>(property: String) -> U? {
        return rlmResults.minOfProperty(property) as! U?
    }

    /**
    Returns the maximum value of the given property.

    :warning: Only names of properties of a type conforming to the `MinMaxType` protocol can be used.

    :param: property The name of a property conforming to `MinMaxType` to look for a maximum on.

    :returns: The maximum value for the property amongst objects in the Results, or `nil` if the Results is empty.
    */
    public func max<U: MinMaxType>(property: String) -> U? {
        return rlmResults.maxOfProperty(property) as! U?
    }

    /**
    Returns the sum of the given property for objects in the Results.

    :warning: Only names of properties of a type conforming to the `AddableType` protocol can be used.

    :param: property The name of a property conforming to `AddableType` to calculate sum on.

    :returns: The sum of the given property over all objects in the Results.
    */
    public func sum<U: AddableType>(property: String) -> U {
        return rlmResults.sumOfProperty(property) as AnyObject as! U
    }

    /**
    Returns the average of the given property for objects in the Results.

    :warning: Only names of properties of a type conforming to the `AddableType` protocol can be used.

    :param: property The name of a property conforming to `AddableType` to calculate average on.

    :returns: The average of the given property over all objects in the Results, or `nil` if the Results is empty.
    */
    public func average<U: AddableType>(property: String) -> U? {
        return rlmResults.averageOfProperty(property) as! U?
    }

    // MARK: Notifications

    /**
     Register a block to be called each time the Results changes.

     The block will be asynchronously called with the initial results, and then
     called again after each writen transaction which causes the results to change.
     You must retain the returned token for as long as you want the results to
     continue to be sent to the block. To stop receiving updates, call stop() on the
     token.

     The determination for whether or not a write transaction has changed the
     results is currently very coarse, and the block may be called even if no
     changes occurred. The opposite (not being called despite changes) will not
     happen. This will become more precise in future versions.

     If an error occurs the block will be called with `nil` for the results
     parameter and a non-`nil` error. Currently the only errors that can occur are
     when opening the Realm on the background worker thread or the destination
     queue fails.

     At the time when the block is called, the Results object will be fully
     evaluated and up-to-date, and as long as you do not perform a write transaction
     on the same thread or explicitly call realm.refresh(), accessing it will never
     perform blocking work.

     :warning: This method cannot be called during a write transaction, or when
               the source realm is read-only.

     :param: block The block to be called with the evaluated results
     :returns: A token which must be held for as long as you want query results to be delivered.
     */
    public func addNotificationBlock(block: (Results<T>?, NSError?) -> ()) -> NotificationToken {
        return rlmResults.addNotificationBlock { results, error in
            if results != nil {
                block(self, nil)
            } else {
                block(nil, error)
            }
        }
    }
}

extension Results: RealmCollectionType {
    // MARK: Sequence Support

    /// Returns a `GeneratorOf<T>` that yields successive elements in the results.
    public func generate() -> RLMGenerator<T> {
        return RLMGenerator(collection: rlmResults)
    }

    // MARK: Collection Support

    /// The position of the first element in a non-empty collection.
    /// Identical to endIndex in an empty collection.
    public var startIndex: Int { return 0 }

    /// The collection's "past the end" position.
    /// endIndex is not a valid argument to subscript, and is always reachable from startIndex by zero or more applications of successor().
    public var endIndex: Int { return count }

    /// :nodoc:
    public func _addNotificationBlock(block: (AnyRealmCollection<T>?, NSError?) -> ()) -> NotificationToken {
        let anyCollection = AnyRealmCollection(self)
        return rlmResults.addNotificationBlock { results, error in
            if results != nil {
                block(anyCollection, nil)
            } else {
                block(nil, error)
            }
        }
    }
}
