//
//  SidebarTableViewController.swift
//  claude
//
//  Created by Tim Tully on 3/9/24.
//

import Foundation
import UIKit
import CoreData
import SideMenu

class SidebarTableviewController : UITableViewController, UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            // Create an action for the menu
            let action1 = UIAction(title: "Action 1", image: nil, identifier: nil) { action in
                // Perform action
            }
            
            // Create another action
            let action2 = UIAction(title: "Action 2", image: nil, identifier: nil) { action in
                // Perform another action
            }
            
            return UIMenu(title: "", children: [action1, action2])
        }
    }
    
    let  cellReuseIdentifier = "history_cell";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Claude"
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (section == 0){
            let all = HistoryDB.shared.getAll()
            return all.count
        }
        else {
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = indexPath.section;
        let row = indexPath.row;
        let all = HistoryDB.shared.getAll()
        if (section == 0) {
            var cell : UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: cellReuseIdentifier)
            }
            cell?.textLabel!.text = all[row]
            
            cell?.textLabel?.numberOfLines = 0
            
            return cell!
        }
        else {  // last row
            var cell : UITableViewCell? = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: cellReuseIdentifier)
            }
            let model = UserDefaults.standard.string(forKey: Constants.PREFERENCE_MODEL_SELECTED)
            if(model == nil || model == "Opus"){
                cell?.textLabel!.text = "Opus"
            }
            else{
                cell?.textLabel!.text = model;
            }
            
            cell?.textLabel?.numberOfLines = 0
            
            return cell!
        }
    }
    
    // method to run when table view cell is tapped
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let all = HistoryDB.shared.getAll()
        let row = indexPath.row;
        
        if(indexPath.section == 0){
            let qt = all[row]
            let dataToSend = ["qt": qt]
            
            NotificationCenter.default.post(name: .RUN_SEARCH, object: nil, userInfo: dataToSend)
            self.dismiss(animated: true)
        }
        else{
        }
    }
    
    func setModel(_ model:String) {
        UserDefaults.standard.set(model, forKey: Constants.PREFERENCE_MODEL_SELECTED);
    }
    
    func refreshModelRow() {
        let indexPath = IndexPath(row: 0, section: 1) // Specify the index path of the row to reload
        tableView.reloadRows(at: [indexPath], with: .automatic) // Choose an animation()
    }
    
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        if (indexPath.section == 0) {return nil}
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            // Create an action for the menu
            let action1 = UIAction(title: "Opus", image: nil, identifier: nil) { [self] action in
                // Perform action
                setModel("Opus")
                refreshModelRow()
            }
            
            // Create another action
            let action2 = UIAction(title: "Sonnet", image: nil, identifier: nil) { [self] action in
                // Perform another action
                setModel("Sonnet")
                refreshModelRow()
            }
            
            let action3 = UIAction(title: "Haiku", image: nil, identifier: nil) { [self] action in
                setModel("Haiku")
                refreshModelRow()
            }
            
            // Return a UIMenu containing the actions
            return UIMenu(title: "", children: [action1, action2, action3])
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0){
            return "Past Queries"
        }
        return "Model Used"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}
