//
//  Item.swift
//  VoxelSprite
//
//  Created by Andreas Pelczer on 03.03.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
