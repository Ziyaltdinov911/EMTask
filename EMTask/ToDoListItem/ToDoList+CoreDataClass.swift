//
//  ToDoList+CoreDataClass.swift
//  EMTask
//
//  Created by Камиль Байдиев on 25.08.2024.
//
//

import Foundation
import CoreData

@objc(ToDoList)
public class ToDoList: NSManagedObject {

}

extension ToDoList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ToDoList> {
        return NSFetchRequest<ToDoList>(entityName: "ToDoList")
    }

    @NSManaged public var name: String?
    @NSManaged public var descriptionText: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var isCompleted: Bool
}

extension ToDoList : Identifiable {

}
