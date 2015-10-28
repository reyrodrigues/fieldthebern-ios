//
//  User.swift
//  GroundGame
//
//  Created by Josh Smith on 10/23/15.
//  Copyright © 2015 Josh Smith. All rights reserved.
//

import Foundation
import SwiftyJSON

struct User {
    let id: String?
    let firstName: String?
    let lastName: String?
    let totalPoints: Int
    let visitsCount: Int
    let photoThumbURL: String?
    let photoLargeURL: String?

    var name: String? {
        get {
            if let first = firstName, last = lastName {
                return "\(first) \(last)"
            } else {
                return firstName
            }
        }
    }
    
    var totalPointsString: String? {
        get {
            let numberFormatter = NSNumberFormatter()
            numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
            return numberFormatter.stringFromNumber(totalPoints)
        }
    }

    var visitsCountString: String? {
        get {
            let numberFormatter = NSNumberFormatter()
            numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
            return numberFormatter.stringFromNumber(visitsCount)
        }
    }

    init(json: JSON) {
        let data = json["data"]
        
        self.id = data["id"].string
        
        let attributes = data["attributes"]
        
        self.firstName = attributes["first_name"].string
        self.lastName = attributes["last_name"].string
        
        if let points = attributes["total_points"].number {
            self.totalPoints = Int(points)
        } else {
            self.totalPoints = 0
        }

        if let count = attributes["visits_count"].number {
            self.visitsCount = Int(count)
        } else {
            self.visitsCount = 0
        }
        
        self.photoThumbURL = attributes["photo_thumb_url"].string
        self.photoLargeURL = attributes["photo_large_url"].string
    }
}