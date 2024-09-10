//
//  Item.swift
//  Color Repeat
//
//  Created by Jada Brunson on 9/10/24.
//

import SwiftData
import Foundation

@Model
class Item {
    @Attribute var points: Int
    @Attribute var date: Date

    init(points: Int, date: Date = Date()) {
        self.points = points
        self.date = date
    }
}

