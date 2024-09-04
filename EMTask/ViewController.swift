//
//  ViewController.swift
//  EMTask
//
//  Created by Камиль Байдиев on 25.08.2024.
//

import UIKit
import CoreData

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    lazy var context: NSManagedObjectContext? = {
        (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
    }()
    
    private lazy var tableView: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.delegate = self
        table.dataSource = self
        return table
    }()
    
    private var models = [ToDoList]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ToDoList"
        view.addSubview(tableView)
        tableView.frame = view.bounds
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(didTapAddButton))
        
        fetchTasksFromAPIIfNeeded()
        fetchAllItems()
    }
    
    @objc private func didTapAddButton() {
        let alert = UIAlertController(title: "Новая задача", message: "Добавьте новую задачу", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "Название задачи"
        }
        alert.addTextField { textField in
            textField.placeholder = "Описание задачи"
        }
        alert.addAction(UIAlertAction(title: "ОК", style: .default, handler: { [weak self] _ in
            guard let fields = alert.textFields, fields.count == 2,
                  let name = fields[0].text, !name.isEmpty,
                  let description = fields[1].text, !description.isEmpty else {
                return
            }
            self?.createItem(name: name, description: description, isCompleted: false)
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - TableView Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return configureCell(tableView, cellForRowAt: indexPath)
    }
    
    private func configureCell(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let model = models[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = model.name
        cell.detailTextLabel?.text = model.descriptionText
        cell.accessoryType = model.isCompleted ? .checkmark : .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = models[indexPath.row]
        
        let sheet = UIAlertController(title: "Меню редактирования задачи", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        sheet.addAction(UIAlertAction(title: "Редактировать", style: .default, handler: { [weak self] _ in
            self?.showEditAlert(for: item)
        }))
        sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { [weak self] _ in
            self?.deleteItem(item: item)
        }))
        sheet.addAction(UIAlertAction(title: item.isCompleted ? "Убрать отметку" : "Поставить отметку", style: .default, handler: { [weak self] _ in
            self?.toggleCompletionStatus(for: item)
        }))
        present(sheet, animated: true)
    }
    
    private func showEditAlert(for item: ToDoList) {
        let alert = UIAlertController(title: "Редактировать задачу", message: "Редактировать мою задачу", preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = item.name
        }
        alert.addTextField { textField in
            textField.text = item.descriptionText
        }
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak self] _ in
            guard let fields = alert.textFields, fields.count == 2,
                  let newName = fields[0].text, !newName.isEmpty,
                  let newDescription = fields[1].text, !newDescription.isEmpty else {
                return
            }
            self?.updateItem(item: item, name: newName, description: newDescription)
        }))
        
        present(alert, animated: true)
    }
    
    // MARK: - Core Data Methods
    
    func fetchAllItems() {
        guard let context = context else { return }
        DispatchQueue.global(qos: .background).async {
            let fetchRequest: NSFetchRequest<ToDoList> = ToDoList.fetchRequest()
            do {
                self.models = try context.fetch(fetchRequest)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } catch {
                print("Failed to fetch items: \(error.localizedDescription)")
            }
        }
    }

    func createItem(name: String, description: String, isCompleted: Bool) {
        guard let context = context else { return }
        let newItem = ToDoList(context: context)
        newItem.name = name
        newItem.descriptionText = description
        newItem.createdAt = Date()
        newItem.isCompleted = isCompleted
        
        DispatchQueue.global(qos: .background).async {
            do {
                try context.save()
                self.fetchAllItems()
            } catch {
                print("Failed to create item: \(error.localizedDescription)")
            }
        }
    }

    func deleteItem(item: ToDoList) {
        guard let context = context else { return }
        context.delete(item)
        
        DispatchQueue.global(qos: .background).async {
            do {
                try context.save()
                self.fetchAllItems()
            } catch {
                print("Failed to delete item: \(error.localizedDescription)")
            }
        }
    }
    
    func updateItem(item: ToDoList, name: String, description: String) {
        guard let context = context else { return }
        item.name = name
        item.descriptionText = description
        
        DispatchQueue.global(qos: .background).async {
            do {
                try context.save()
                self.fetchAllItems()
            } catch {
                print("Failed to update item: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleCompletionStatus(for item: ToDoList) {
        guard let context = context else { return }
        item.isCompleted.toggle()
        
        DispatchQueue.global(qos: .background).async {
            do {
                try context.save()
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } catch {
                print("Failed to update item completion status: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - API Integration
    
    private func fetchTasksFromAPIIfNeeded() {
        if models.isEmpty {
            fetchTasksFromAPI()
        }
    }

    private func fetchTasksFromAPI() {
        guard let url = URL(string: "https://dummyjson.com/todos") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, error == nil else { return }
            
            do {
                let jsonResult = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let todos = jsonResult?["todos"] as? [[String: Any]] {
                    for todo in todos {
                        let name = todo["todo"] as? String ?? "No Title"
                        let description = todo["description"] as? String ?? "No Description"
                        let isCompleted = todo["completed"] as? Bool ?? false
                        
                        self.createItem(name: name, description: description, isCompleted: isCompleted)
                    }
                }
            } catch {
                print("Failed to parse JSON: \(error.localizedDescription)")
            }
        }.resume()
    }
}
