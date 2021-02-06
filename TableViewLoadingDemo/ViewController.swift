import UIKit

class ViewController: UIViewController {

    let tableView = UITableView(frame: .zero, style: .plain)
    var dataSource: UITableViewDiffableDataSource<Section, Model>!
    let dataProvider = DataProvider()
    var isLoading = false

    var lastScrollOffset: CGFloat?
    var isScrollingUp = false
    var isDragging = false
    var hasPendingChange = false

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Demo"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(loadMore))

        makeDataSource()

        tableView.separatorStyle = .none
        tableView.register(Cell.self, forCellReuseIdentifier: "DefaultCell")
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    func makeDataSource() {
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { tableView, indexPath, model -> UITableViewCell? in
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath) as! Cell
            cell.update(model)
            return cell
        }
    }

    func applySnapshot() {
        // NOTE: Trying to apply snapshot while user is dragging causes weird jumps, deferring snapshot application helps
        if isDragging  {
            print("applySnapshot - bailed")
            hasPendingChange = true
            return
        }

        print("applySnapshot")

        var snapshot = NSDiffableDataSourceSnapshot<Section, Model>()
        snapshot.appendSections([.main])
        snapshot.appendItems(dataProvider.models, toSection: .main)

        dataSource.defaultRowAnimation = .automatic

        // NOTE: scrolling animation is fine if it is not top of content,
        // otherwise if the first row is showing and the content is reloaded, the offset will jump to the very first content
        let shouldAdjustScrollPosition = tableView.indexPathsForVisibleRows?.first(where: { $0.row == 0 }) != nil
        let initialContentHeight = tableView.contentSize.height

        dataSource.apply(snapshot, animatingDifferences: !shouldAdjustScrollPosition) {}

        if shouldAdjustScrollPosition {
            let finalContentHeight = tableView.contentSize.height
            tableView.contentOffset.y += (finalContentHeight - initialContentHeight)
        }
    }

    func applySnapshot(_ models: [Model]) {
        if isDragging  {
            hasPendingChange = true
            return
        }

        // NOTE: Apply delta does not help with diff animation
        var snapshot = dataSource.snapshot()
        if snapshot.numberOfSections > 0, let firstItem = snapshot.itemIdentifiers(inSection: .main).first {
            snapshot.insertItems(models, beforeItem: firstItem)
        } else {
            snapshot.appendSections([.main])
            snapshot.appendItems(models, toSection: .main)
        }

        dataSource.defaultRowAnimation = .automatic
        dataSource.apply(snapshot, animatingDifferences: true) {}
    }

    @objc func loadMore() {
        guard !isLoading && !hasPendingChange else { return }
        isLoading = true

        print("loadMore")

        dataProvider.loadMore { models in
            DispatchQueue.main.async {
                self.applySnapshot()
                self.isLoading = false
            }
        }
    }
}

extension ViewController: UITableViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // initial contentOffset.y = -94
        // initial adjustedContentInset.top = 94

        let offsetTop = scrollView.contentOffset.y + scrollView.adjustedContentInset.top

        if let lastScrollOffset = lastScrollOffset {
            isScrollingUp = lastScrollOffset > offsetTop
        }
        // NOTE: checking both scroll direction and offset to top reduces unexpected event trigger
        if isScrollingUp && offsetTop < 400 {
            loadMore()
        }

        lastScrollOffset = offsetTop
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("scrollViewDidEndDecelerating")
        isScrollingUp = false
        lastScrollOffset = nil
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isDragging = true
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("scrollViewDidEndDragging")
        isDragging = false
        if hasPendingChange {
            hasPendingChange = false
            applySnapshot()
        }
    }
}

class Cell: UITableViewCell {
    let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        contentView.layoutMargins = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        contentView.preservesSuperviewLayoutMargins = false

        label.textColor = .label
        label.backgroundColor = .secondarySystemBackground
        label.layer.cornerRadius = 8
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ model: Model) {
        label.text = model.text
    }
}

enum Section: Equatable, Hashable {
    case main
}

struct Model: Equatable, Hashable {
    let id: String
    let text: String
}

class DataProvider {
    let queue = DispatchQueue(label: "dataQueue")

    var models: [Model] = []
    var counter = 0

    init() {}

    func loadMore(completion: @escaping ([Model]) -> ()) {
        queue.asyncAfter(deadline: .now() + 0.5) {
            var newModels: [Model] = []
            (0..<20).forEach { _ in
                let model = self.newModel()
                newModels.insert(model, at: 0)
                self.models.insert(model, at: 0)
            }
            completion(newModels)
        }
    }

    private func newModel() -> Model {
        counter += 1
        return Model(id: "id-\(counter)", text: "Hello World - \(counter)")
    }
}
