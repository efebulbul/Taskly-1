import UIKit
import UserNotifications
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import SwiftUI


// MARK: - Renk
extension UIColor {
    static var appBlueOrFallback: UIColor {
        UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)
    }
}

// MARK: - Model (Firestore uyumlu)
struct Task: Codable, Equatable, Identifiable {
    @DocumentID var id: String?
    var title: String
    var emoji: String
    var done: Bool
    var dueDate: Date?
    var notes: String?
    @ServerTimestamp var createdAt: Date?

  
    init(id: String? = nil,
         title: String,
         emoji: String,
         done: Bool,
         dueDate: Date? = nil,
         notes: String? = nil,
         createdAt: Date? = nil) {
        self.id = id
        self.title = title
        self.emoji = emoji
        self.done = done
        self.dueDate = dueDate
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Yerel Bildirim Zamanlayıcı (30 dk önce + tam saatinde)
enum ReminderScheduler {
    static func schedule(for task: Task) {
        guard let due = task.dueDate, !task.done else { return }
        let center = UNUserNotificationCenter.current()
     
        cancel(for: task)

        let now = Date()

        
        if due > now {
            let contentAt = UNMutableNotificationContent()
            contentAt.title = L("reminder.dueNow.title")
            contentAt.body  = task.title
            contentAt.sound = .default
            let triggerAt = UNCalendarNotificationTrigger(dateMatching: calendarComponents(from: due), repeats: false)
            let reqAt = UNNotificationRequest(identifier: id(task, suffix: "at"), content: contentAt, trigger: triggerAt)
            center.add(reqAt, withCompletionHandler: nil)
        }

        
        let before = due.addingTimeInterval(-30 * 60)
        if before > now {
            let contentBefore = UNMutableNotificationContent()
            contentBefore.title = L("reminder.thirtyMins.title")
            contentBefore.body  = task.title
            contentBefore.sound = .default
            let triggerBefore = UNCalendarNotificationTrigger(dateMatching: calendarComponents(from: before), repeats: false)
            let reqBefore = UNNotificationRequest(identifier: id(task, suffix: "30m"), content: contentBefore, trigger: triggerBefore)
            center.add(reqBefore, withCompletionHandler: nil)
        }
    }

    static func cancel(for task: Task) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id(task, suffix: "at"), id(task, suffix: "30m")]
        )
    }

    private static func id(_ task: Task, suffix: String) -> String {
        (task.id ?? UUID().uuidString) + "#" + suffix
    }

    private static func calendarComponents(from date: Date) -> DateComponents {
        var cal = Calendar.current
        cal.locale = LanguageManager.shared.currentLocale
        return cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }
}

// MARK: - ItemsViewController
final class ItemsViewController: UITableViewController {

    // Firestore-backed kalıcılık
    private var tasks: [Task] = [] {
        didSet { refreshEmptyState() }
    }

    // MARK: - Firestore
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Kategoriler (kişiselleştirilebilir, 4 adet)
    private let categoriesStorageKey = "categories.v1"
    private var categories: [String] = [] { didSet { saveCategories() } }

    // Filtre (nil = Tümü)
    private var activeFilter: String? = nil
    private let filterControl = UISegmentedControl(items: [])

    // Sadece bugünün görevlerini göster
    private var showTodayOnly = false
    // Sadece bu haftanın (Pazartesi–Pazar) görevlerini göster
    private var showThisWeekOnly = false
    // Sadece süresi geçmiş (tamamlanmamış) görevleri göster
    private var showOverdueOnly = false

    // TR tarih/saat formatter
    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = LanguageManager.shared.currentLocale
        return f
    }()

    
    private let defaultCategories = ["📝","💼","🏠","🏃🏻"]

    private func loadCategories() {
        if let saved = UserDefaults.standard.array(forKey: categoriesStorageKey) as? [String], saved.count == 4 {
            categories = saved
        } else {
            categories = defaultCategories
        }
    }

    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: categoriesStorageKey)
    }

    private func isInCurrentWeek(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return false
        }
        return weekInterval.contains(date)
    }

    private var pending: [Task] {
        tasks.filter {
            !$0.done &&
            (activeFilter == nil || $0.emoji == activeFilter) &&
            (!showTodayOnly || Calendar.current.isDateInToday($0.dueDate ?? Date.distantPast)) &&
            (!showThisWeekOnly || isInCurrentWeek($0.dueDate)) &&
            (!showOverdueOnly || (($0.dueDate ?? Date.distantFuture) < Date() && !$0.done))
        }
    }
    private var completed: [Task] {
        tasks.filter {
            $0.done &&
            (activeFilter == nil || $0.emoji == activeFilter) &&
            (!showTodayOnly || Calendar.current.isDateInToday($0.dueDate ?? Date.distantPast)) &&
            (!showThisWeekOnly || isInCurrentWeek($0.dueDate))
        }
    }

    
    private lazy var addButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "plus"), for: .normal)
        b.setPreferredSymbolConfiguration(UIImage.SymbolConfiguration(pointSize: 28, weight: .bold), forImageIn: .normal)
        b.tintColor = .white
        b.backgroundColor = .appBlueOrFallback
        b.layer.cornerRadius = 32
        b.layer.shadowOpacity = 0.25
        b.layer.shadowRadius = 6
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 64).isActive = true
        b.heightAnchor.constraint(equalToConstant: 64).isActive = true
        b.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        return b
    }()

    private let emptyView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = L("items.title")
        navigationController?.navigationBar.prefersLargeTitles = false
        NotificationCenter.default.addObserver(self, selector: #selector(reloadForLanguage), name: .languageDidChange, object: nil)

        // MARK: Brand in Navigation Bar (el yazısı güçlü stil)
        let brandContainer = UIStackView()
        brandContainer.axis = .horizontal
        brandContainer.alignment = .center
        brandContainer.spacing = -2

        let taskLabel = UILabel()
        taskLabel.text = "Task"
        taskLabel.textColor = .label
        taskLabel.font = .systemFont(ofSize: 30, weight: .semibold)

        let lyLabel = UILabel()
        lyLabel.textColor = .appBlueOrFallback
        lyLabel.font = .systemFont(ofSize: 30, weight: .semibold)
        lyLabel.text = "ly"

        brandContainer.addArrangedSubview(taskLabel)
        brandContainer.addArrangedSubview(lyLabel)

        let brandWrapper = UIView()
        brandWrapper.addSubview(brandContainer)
        brandContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brandContainer.leadingAnchor.constraint(equalTo: brandWrapper.leadingAnchor),
            brandWrapper.trailingAnchor.constraint(equalTo: brandContainer.trailingAnchor),
            brandContainer.topAnchor.constraint(equalTo: brandWrapper.topAnchor),
            brandWrapper.bottomAnchor.constraint(equalTo: brandContainer.bottomAnchor)
        ])

        navigationItem.titleView = brandWrapper

        // Filtre butonu (sol üstte ünlem)
        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(presentFilterSheet)
        )
        navigationItem.leftBarButtonItem = filterButton

        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "TaskCell")
        tableView.rowHeight = 56
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .systemGroupedBackground
        if #available(iOS 15.0, *) { tableView.sectionHeaderTopPadding = 8 }

        loadCategories()
        setupFilterControl()
        tableView.tableHeaderView = makeHeaderContainer(for: filterControl)

        view.addSubview(addButton)
        NSLayoutConstraint.activate([
            addButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])

        emptyView.configure(
            title: L("empty.title"),
            subtitle: L("empty.subtitle"),
            buttonTitle: L("empty.cta")
        )
        emptyView.onPrimaryTap = { [weak self] in self?.presentAddTask() }

        startObservingTasks()
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidLogin), name: .tasklyDidLogin, object: nil)
        refreshEmptyState()
    }

    private func setupFilterControl() {
        
        let previousIndex = filterControl.selectedSegmentIndex

        filterControl.removeAllSegments()
        filterControl.insertSegment(withTitle: L("filter.all"), at: 0, animated: false)
        for (idx, e) in categories.enumerated() {
            filterControl.insertSegment(withTitle: e, at: idx + 1, animated: false)
        }
        // Eski seçim korunamazsa Tümü yap
        if previousIndex != UISegmentedControl.noSegment && previousIndex < filterControl.numberOfSegments {
            filterControl.selectedSegmentIndex = previousIndex
        } else {
            filterControl.selectedSegmentIndex = 0
        }

        filterControl.removeTarget(nil, action: nil, for: .allEvents)
        filterControl.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
        filterControl.translatesAutoresizingMaskIntoConstraints = false

        
        let alreadyHasLP = filterControl.gestureRecognizers?.contains(where: { $0 is UILongPressGestureRecognizer }) ?? false
        if !alreadyHasLP {
            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleCategoryLongPress(_:)))
            filterControl.addGestureRecognizer(lp)
        }
    }

   
    private func makeHeaderContainer(for view: UIView) -> UIView {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 54))
        container.backgroundColor = .clear
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 16),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        if sender.selectedSegmentIndex == 0 {
            activeFilter = nil
        } else {
            let idx = sender.selectedSegmentIndex - 1
            activeFilter = categories.indices.contains(idx) ? categories[idx] : nil
        }
        tableView.reloadData()
        refreshEmptyState()
    }

    @objc private func presentFilterSheet() {
        let ac = UIAlertController(
            title: L("filter.sheet.title"),
            message: nil,
            preferredStyle: .actionSheet
        )

        
        ac.addAction(UIAlertAction(title: L("filter.menu.allTasks"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showTodayOnly = false
            self.showThisWeekOnly = false
            self.showOverdueOnly = false
            self.tableView.reloadData()
            self.refreshEmptyState()
        }))

        
        ac.addAction(UIAlertAction(title: L("filter.menu.todayTasks"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showTodayOnly = true
            self.showThisWeekOnly = false
            self.showOverdueOnly = false
            self.tableView.reloadData()
            self.refreshEmptyState()
        }))

        ac.addAction(UIAlertAction(title: L("filter.menu.weekTasks"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showTodayOnly = false
            self.showThisWeekOnly = true
            self.showOverdueOnly = false
            self.tableView.reloadData()
            self.refreshEmptyState()
        }))

    
        ac.addAction(UIAlertAction(title: L("filter.menu.overdueTasks"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.showTodayOnly = false
            self.showThisWeekOnly = false
            self.showOverdueOnly = true
            self.tableView.reloadData()
            self.refreshEmptyState()
        }))

        ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.barButtonItem = navigationItem.leftBarButtonItem
        }

        present(ac, animated: true)
    }
   
    @objc private func handleCategoryLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        let point = gr.location(in: filterControl)
        guard filterControl.numberOfSegments > 0 else { return }
        let segmentWidth = filterControl.bounds.width / CGFloat(filterControl.numberOfSegments)
        var index = Int(point.x / segmentWidth)
        index = max(0, min(index, filterControl.numberOfSegments - 1))
        // 0: Tümü (düzenlenemez)
        guard index > 0 else { return }
        let catIdx = index - 1
        guard categories.indices.contains(catIdx) else { return }

        let current = categories[catIdx]
        let ac = UIAlertController(title: L("cat.edit.title"),
                                   message: L("cat.edit.message"),
                                   preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = "🔖"
            tf.text = current
        }
        ac.addAction(UIAlertAction(title: L("common.cancel"), style: .cancel))
        ac.addAction(UIAlertAction(title: L("common.save"), style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let text = ac.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard text.isSingleEmoji else {
                self.showAlert(title: L("cat.invalid.title"), message: L("cat.invalid.message"))
                return
            }
            self.categories[catIdx] = text
            // Seçili segment buysa aktif filtreyi de güncelle
            if self.filterControl.selectedSegmentIndex == index { self.activeFilter = text }
            self.setupFilterControl()
            self.tableView.reloadData()
            self.refreshEmptyState()
        }))
        present(ac, animated: true)
    }

    private func refreshEmptyState() {
        tableView.backgroundView = tasks.isEmpty ? emptyView : nil
    }

    // MARK: - Firestore listening
    private func startObservingTasks() {
     
        listener?.remove()

        guard let uid = Auth.auth().currentUser?.uid else {
            tasks = []
            tableView.reloadData()
            return
        }

        listener = db.collection("users")
            .document(uid)
            .collection("tasks")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    let proj = FirebaseApp.app()?.options.projectID ?? "nil"
                    let uidLog = Auth.auth().currentUser?.uid ?? "nil"
                    print("⚠️ Tasks listen error:", error.localizedDescription, "| ProjectID:", proj, "| UID:", uidLog)
                    return
                }
                DispatchQueue.main.async {
                    self.tasks = snapshot?.documents.compactMap { try? $0.data(as: Task.self) } ?? []
                    self.tableView.reloadData()
                }
            }
    }

    @objc private func handleDidLogin() {
        startObservingTasks()
    }

    // MARK: Sections
    override func numberOfSections(in tableView: UITableView) -> Int {
        if tasks.isEmpty { return 0 }
     
        return showOverdueOnly ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if showOverdueOnly {
           
            return L("list.section.pending")
        } else {
            return section == 0 ? L("list.section.pending") : L("list.section.done")
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showOverdueOnly {
            
            return pending.count
        } else {
            return section == 0 ? pending.count : completed.count
        }
    }

    private func item(at indexPath: IndexPath) -> Task {
        if showOverdueOnly {
  
            return pending[indexPath.row]
        } else {
            return indexPath.section == 0 ? pending[indexPath.row] : completed[indexPath.row]
        }
    }

    private func globalIndex(from indexPath: IndexPath) -> Int? {
        let t = item(at: indexPath)
        return tasks.firstIndex(where: { $0.id == t.id })
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath)
        let it = item(at: indexPath)

        var cfg = cell.defaultContentConfiguration()
        
        cfg.attributedText = nil
        cfg.text = it.title
        if it.done {
            cfg.textProperties.font  = .systemFont(ofSize: 16, weight: .regular)
            cfg.textProperties.color = .secondaryLabel
        } else {
            cfg.textProperties.font  = .systemFont(ofSize: 16, weight: .semibold)
            cfg.textProperties.color = .label
        }
        cfg.image = UIImage(systemName: it.done ? "checkmark.circle.fill" : "circle")
        cfg.imageProperties.tintColor = it.done ? .systemGreen : .tertiaryLabel
        cfg.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        // Secondary text: notes + dueDate
        let hasNotes = !(it.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasDate = it.dueDate != nil
        if hasNotes && hasDate {
            let notesText = it.notes!.trimmingCharacters(in: .whitespacesAndNewlines)
            cfg.secondaryText = "\(notesText) • \(dateFormatter.string(from: it.dueDate!))"
        } else if hasNotes {
            cfg.secondaryText = it.notes!.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if hasDate {
            cfg.secondaryText = dateFormatter.string(from: it.dueDate!)
        } else {
            cfg.secondaryText = nil
        }
        cfg.secondaryTextProperties.color = .secondaryLabel

       
        let emoji = UILabel()
        emoji.text = it.emoji
        emoji.font = .systemFont(ofSize: 20)
        let acc = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        emoji.translatesAutoresizingMaskIntoConstraints = false
        acc.addSubview(emoji)
        NSLayoutConstraint.activate([
            emoji.centerXAnchor.constraint(equalTo: acc.centerXAnchor),
            emoji.centerYAnchor.constraint(equalTo: acc.centerYAnchor)
        ])
        cell.accessoryView = acc
        cell.contentConfiguration = cfg

        
        var bg = UIBackgroundConfiguration.listGroupedCell()
        bg.backgroundColor = .secondarySystemGroupedBackground
        cell.backgroundConfiguration = bg
        cell.layer.cornerRadius = 12
        cell.layer.masksToBounds = true

  
        let sel = UIView()
        sel.backgroundColor = (UIColor(named: "AppBlue") ?? UIColor(red: 0/255, green: 111/255, blue: 255/255, alpha: 1)).withAlphaComponent(0.12)
        sel.layer.cornerRadius = 12
        sel.layer.masksToBounds = true
        cell.selectedBackgroundView = sel

        return cell
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let t = item(at: indexPath)
        let vc = TaskDetailViewController(task: t)
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        vc.modalPresentationStyle = .pageSheet
        vc.modalTransitionStyle = .coverVertical
        present(vc, animated: true)
    }

    // MARK: Swipe
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: L("actions.delete")) { [weak self] _,_,done in
            guard let self = self else { return }
            if let gi = self.globalIndex(from: indexPath) {
                let task = self.tasks[gi]
             
                DispatchQueue.main.async {
                    self.tasks.removeAll { $0.id == task.id }
                    self.tableView.reloadData()
                    self.refreshEmptyState()
                }
                ReminderScheduler.cancel(for: task)
                if let id = task.id, let uid = Auth.auth().currentUser?.uid {
                    self.db.collection("users").document(uid).collection("tasks").document(id).delete { err in
                        if let err = err {
                            let proj = FirebaseApp.app()?.options.projectID ?? "nil"
                            print("Delete error:", err.localizedDescription, "| ProjectID:", proj)
                        }
                    
                    }
                }
            }
            done(true)
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(_ tableView: UITableView,
                            leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let t = item(at: indexPath)
        let title = t.done ? L("actions.undo") : L("actions.complete")
        let action = UIContextualAction(style: .normal, title: title) { [weak self] _,_,done in
            guard let self = self, let gi = self.globalIndex(from: indexPath) else { return }
            var target = self.tasks[gi]
            let newDone = !target.done
            target.done = newDone
            DispatchQueue.main.async {
                self.tasks[gi].done = newDone
                self.tableView.reloadData()
                self.refreshEmptyState()
            }

            if newDone {
                ReminderScheduler.cancel(for: target)
            } else {
                ReminderScheduler.schedule(for: target)
            }

            if let id = target.id, let uid = Auth.auth().currentUser?.uid {
                self.db.collection("users").document(uid).collection("tasks").document(id)
                    .updateData(["done": newDone]) { err in
                        if let err = err {
                            let proj = FirebaseApp.app()?.options.projectID ?? "nil"
                            print("Toggle error:", err.localizedDescription, "| ProjectID:", proj)
                        }
                    }
            }
            done(true)
        }
        action.image = UIImage(systemName: t.done ? "arrow.uturn.left" : "checkmark")
        action.backgroundColor = t.done ? .systemGray : .systemGreen
        return UISwipeActionsConfiguration(actions: [action])
    }

    // MARK: Add
    @objc private func addTapped() { presentAddTask() }

    private func presentAddTask() {
        let ac = UIAlertController(title: L("add.title"),
                                   message: L("add.message"),
                                   preferredStyle: .alert)
        // Başlık
        ac.addTextField { tf in
            tf.placeholder = L("add.placeholder.title")
            tf.autocapitalizationType = .sentences
        }
        // Açıklama
        ac.addTextField { tf in
            tf.placeholder = L("add.placeholder.notes")
            tf.autocapitalizationType = .sentences
        }

        let pickerVC = UIViewController()
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.locale = LanguageManager.shared.currentLocale
        var cal = Calendar.current; cal.locale = LanguageManager.shared.currentLocale
        picker.calendar = cal
        if #available(iOS 13.4, *) { picker.preferredDatePickerStyle = .wheels }
        picker.minimumDate = Date()
        picker.translatesAutoresizingMaskIntoConstraints = false
        pickerVC.view.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: pickerVC.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: pickerVC.view.trailingAnchor),
            picker.topAnchor.constraint(equalTo: pickerVC.view.topAnchor),
            picker.bottomAnchor.constraint(equalTo: pickerVC.view.bottomAnchor),
            picker.heightAnchor.constraint(equalToConstant: 180)
        ])
        pickerVC.preferredContentSize = CGSize(width: 270, height: 180)
        ac.setValue(pickerVC, forKey: "contentViewController")

        ac.addAction(UIAlertAction(title: L("add.cancel"), style: .cancel))

        ac.addAction(UIAlertAction(title: L("add.add"), style: .default, handler: { [weak self, weak ac] _ in
            guard let self = self else { return }
            let rawTitle = ac?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !rawTitle.isEmpty else {
                self.showAlert(title: L("alerts.missing.title"), message: L("alerts.missing.message"))
                return
            }
            // Açıklama (opsiyonel)
            let rawNotes = ac?.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalNotes: String? = rawNotes.isEmpty ? nil : rawNotes

            let addTask: (String) -> Void = { chosenEmoji in
                let due = picker.date
                guard let uid = Auth.auth().currentUser?.uid else {
                    self.showAlert(title: L("auth.required.title"), message: L("auth.required.message"))
                    return
                }
                let col = self.db.collection("users").document(uid).collection("tasks")
                let doc = col.document()
                let data: [String: Any?] = [
                    "title": rawTitle,
                    "emoji": chosenEmoji,
                    "done": false,
                    "dueDate": due,
                    "notes": finalNotes,
                    "createdAt": Timestamp(date: Date()),
                    
                ]
                doc.setData(data.compactMapValues { $0 }, merge: true) { err in
                    if let err = err {
                        let proj = FirebaseApp.app()?.options.projectID ?? "nil"
                        print("⚠️ Add task error:", err.localizedDescription, "| ProjectID:", proj, "| UID:", uid)
                        self.showAlert(title: L("common.error"), message: L("tasks.add.failed") + "\n" + err.localizedDescription)
                        return
                    }
                    let scheduled = Task(id: doc.documentID, title: rawTitle, emoji: chosenEmoji, done: false, dueDate: due, notes: finalNotes, createdAt: nil)
                    ReminderScheduler.schedule(for: scheduled)
                    DispatchQueue.main.async {
                        var immediate = scheduled
                        immediate.createdAt = Date()
                        self.tasks.append(immediate)
                        self.tableView.reloadData()
                        self.refreshEmptyState()
                    }
                }
            }

            if let chosen = self.activeFilter {
                addTask(chosen)
            } else {
                let chooser = UIAlertController(title: L("add.choose.category"), message: nil, preferredStyle: .actionSheet)
                for e in self.categories {
                    chooser.addAction(UIAlertAction(title: e, style: .default, handler: { _ in addTask(e) }))
                }
                chooser.addAction(UIAlertAction(title: L("add.back"), style: .cancel))
                if let pop = chooser.popoverPresentationController {
                    pop.sourceView = self.view
                    pop.sourceRect = CGRect(x: self.view.bounds.midX, y: 80, width: 1, height: 1)
                }
                self.present(chooser, animated: true)
            }
        }))

        present(ac, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let ac = UIAlertController(title: title, message: message, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: L("settings.ok"), style: .default))
        present(ac, animated: true)
    }

    @objc private func reloadForLanguage() {
        // Refresh navigation title
        title = L("items.title")
        // Update formatter locale
        dateFormatter.locale = LanguageManager.shared.currentLocale
        // Rebuild segmented control first segment title
        setupFilterControl()
        // Refresh empty state texts
        emptyView.configure(
            title: L("empty.title"),
            subtitle: L("empty.subtitle"),
            buttonTitle: L("empty.cta")
        )
        tableView.reloadData()
        refreshEmptyState()
    }

    deinit {
        listener?.remove()
        NotificationCenter.default.removeObserver(self, name: .languageDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: .tasklyDidLogin, object: nil)
    }
}

// MARK: - Task Detail
final class TaskDetailViewController: UIViewController {

    private let task: Task

    // UI
    private let stack = UIStackView()
    private let emojiLabel = UILabel()
    private let titleLabel = UILabel()
    private let dateRow = UIStackView()
    private let dateIcon = UIImageView(image: UIImage(systemName: "calendar"))
    private let dateLabel = UILabel()
    private let notesTitleLabel = UILabel()
    private let notesLabel = UILabel()

    private lazy var df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = LanguageManager.shared.currentLocale
        return f
    }()

    init(task: Task) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L("detail.title")
        navigationItem.largeTitleDisplayMode = .never

        // Ana dikey stack
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])

        // Emoji
        emojiLabel.text = task.emoji
        emojiLabel.font = .systemFont(ofSize: 54)
        emojiLabel.textAlignment = .center
        let emojiContainer = UIView()
        emojiContainer.translatesAutoresizingMaskIntoConstraints = false
        emojiContainer.addSubview(emojiLabel)
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            emojiLabel.topAnchor.constraint(equalTo: emojiContainer.topAnchor),
            emojiLabel.centerXAnchor.constraint(equalTo: emojiContainer.centerXAnchor),
            emojiLabel.bottomAnchor.constraint(equalTo: emojiContainer.bottomAnchor)
        ])

        // Başlık
        titleLabel.text = task.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        // Tarih satırı
        dateRow.axis = .horizontal
        dateRow.alignment = .center
        dateRow.spacing = 8
        dateIcon.tintColor = .appBlueOrFallback
        dateIcon.contentMode = .scaleAspectFit
        dateIcon.setContentHuggingPriority(.required, for: .horizontal)
        if let d = task.dueDate {
            dateLabel.text = df.string(from: d)
            dateLabel.textColor = .secondaryLabel
        } else {
            dateLabel.text = L("detail.no.date")
            dateLabel.textColor = .tertiaryLabel
        }
        dateLabel.textAlignment = .center
        dateRow.addArrangedSubview(dateIcon)
        dateRow.addArrangedSubview(dateLabel)

        // Notlar başlığı
        notesTitleLabel.text = L("detail.notes")
        notesTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        notesTitleLabel.textAlignment = .center

        // Notlar içeriği
        if let n = task.notes, !n.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesLabel.text = n
            notesLabel.textColor = .label
        } else {
            notesLabel.text = "—"
            notesLabel.textColor = .tertiaryLabel
        }
        notesLabel.numberOfLines = 0
        notesLabel.textAlignment = .center

        // Kart benzeri arka plan
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let cardStack = UIStackView(arrangedSubviews: [titleLabel, dateRow])
        cardStack.axis = .vertical
        cardStack.alignment = .fill
        cardStack.spacing = 8
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardStack)
        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            cardStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        let notesCard = UIView()
        notesCard.backgroundColor = UIColor.secondarySystemBackground
        notesCard.layer.cornerRadius = 14
        notesCard.translatesAutoresizingMaskIntoConstraints = false
        let notesStack = UIStackView(arrangedSubviews: [notesTitleLabel, notesLabel])
        notesStack.axis = .vertical
        notesStack.alignment = .fill
        notesStack.spacing = 6
        notesStack.translatesAutoresizingMaskIntoConstraints = false
        notesCard.addSubview(notesStack)
        NSLayoutConstraint.activate([
            notesStack.leadingAnchor.constraint(equalTo: notesCard.leadingAnchor, constant: 16),
            notesStack.trailingAnchor.constraint(equalTo: notesCard.trailingAnchor, constant: -16),
            notesStack.topAnchor.constraint(equalTo: notesCard.topAnchor, constant: 16),
            notesStack.bottomAnchor.constraint(equalTo: notesCard.bottomAnchor, constant: -16)
        ])

        stack.addArrangedSubview(emojiContainer)
        stack.addArrangedSubview(card)
        stack.addArrangedSubview(notesCard)
    }
}

// MARK: - EmptyStateView
final class EmptyStateView: UIView {

    var onPrimaryTap: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let stack = UIStackView()

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = .clear
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            trailingAnchor.constraint(greaterThanOrEqualTo: stack.trailingAnchor, constant: 24)
        ])

        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center

        subtitleLabel.font = .systemFont(ofSize: 15)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        actionButton.backgroundColor = .appBlueOrFallback
        actionButton.layer.cornerRadius = 12
        if #available(iOS 15.0, *) {
            var config = actionButton.configuration ?? UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 18, bottom: 12, trailing: 18)
            actionButton.configuration = config
        } else {
            actionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        }
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.addArrangedSubview(actionButton)
    }

    func configure(title: String, subtitle: String?, buttonTitle: String, buttonColor: UIColor = .appBlueOrFallback) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle ?? "").isEmpty
        actionButton.setTitle(buttonTitle, for: .normal)
        actionButton.backgroundColor = buttonColor
    }

    @objc private func buttonTapped() { onPrimaryTap?() }
}

#Preview {
    ViewControllerPreview {
        ItemsViewController()
    }
}

// MARK: - Emoji doğrulama 
private extension String {
    var isSingleEmoji: Bool { count == 1 && first?.isEmoji == true }
}
private extension Character {
    var isEmoji: Bool { unicodeScalars.contains { $0.properties.isEmoji } }
}
