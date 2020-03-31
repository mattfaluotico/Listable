//
//  PresentationState.swift
//  Listable
//
//  Created by Kyle Van Essen on 7/22/19.
//


protocol AnyPresentationItemState : AnyObject
{
    var isDisplayed : Bool { get }
    func setAndPerform(isDisplayed: Bool)
    
    var itemPosition : ItemPosition { get set }
    
    var anyModel : AnyItem { get }
    
    var reorderingActions : ReorderingActions { get }
    
    var cellRegistrationInfo : (class:AnyClass, reuseIdentifier:String) { get }
    
    func dequeueAndPrepareCollectionViewCell(in collectionView : UICollectionView, for indexPath : IndexPath) -> UICollectionViewCell
    
    func applyTo(cell anyCell : UICollectionViewCell, itemState : Listable.ItemState, reason : ApplyReason)
    func applyToVisibleCell()
        
    func setNew(item anyItem : AnyItem, reason : UpdateReason)
    
    func willDisplay(cell : UICollectionViewCell, in collectionView : UICollectionView, for indexPath : IndexPath)
    func didEndDisplay()
    
    func performUserDidSelectItem(isSelected: Bool)
    
    func resetCachedHeights()
    func height(width : CGFloat, layoutDirection : LayoutDirection, defaultHeight : CGFloat, measurementCache : ReusableViewCache) -> CGFloat
    
    func moved(with result : Reordering.Result)
}


protocol AnyPresentationHeaderFooterState : AnyObject
{
    var anyModel : AnyHeaderFooter { get }
        
    func dequeueAndPrepareReusableHeaderFooterView(in cache : ReusableViewCache, frame : CGRect) -> UIView
    func enqueueReusableHeaderFooterView(_ view : UIView, in cache : ReusableViewCache)
    
    func applyTo(view anyView : UIView, reason : ApplyReason)
    
    func setNew(headerFooter anyHeaderFooter : AnyHeaderFooter)
    
    func resetCachedHeights()
    func height(width : CGFloat, layoutDirection : LayoutDirection, defaultHeight : CGFloat, measurementCache : ReusableViewCache) -> CGFloat
}


enum UpdateReason
{
    case move
    case update
    case noChange
}


/*
 A class used to manage the "live" / mutable state of the visible items in the collection.
 which is persistent across diffs of content (instances are only created or destroyed when an item enters or leaves the table).
 
 This is where bindings or other update-driving objects live,
 which then push the changes to the item and section content back into view models.
 */
final class PresentationState
{
    //
    // MARK: Public Properties
    //
    
    unowned var view : ListView!
    
    var refreshControl : RefreshControl.PresentationState?
    
    var header : HeaderFooterViewStatePair = .init()
    var footer : HeaderFooterViewStatePair = .init()
    var overscrollFooter : HeaderFooterViewStatePair = .init()
    
    var sections : [PresentationState.SectionState]
        
    private(set) var containsAllItems : Bool
    
    private(set) var contentIdentifier : AnyHashable?
    
    //
    // MARK: Initialization
    //
        
    init()
    {
        self.refreshControl = nil
        self.sections = []
        
        self.containsAllItems = true
        
        self.contentIdentifier = nil
    }
    
    //
    // MARK: Accessing Data
    //
    
    var sectionModels : [Section] {
        return self.sections.map { section in
            var sectionModel = section.model
            
            sectionModel.items = section.items.map {
                $0.anyModel
            }
            
            return sectionModel
        }
    }
    
    var selectedIndexPaths : [IndexPath] {
        let indexes : [[IndexPath]] = self.sections.compactMapWithIndex { sectionIndex, _, section in
            return section.items.compactMapWithIndex { itemIndex, _, item in
                if item.anyModel.selection.isSelected {
                    return IndexPath(item: itemIndex, section: sectionIndex)
                } else {
                    return nil
                }
            }
        }
        
        return indexes.flatMap { $0 }
    }
    
    func item(at indexPath : IndexPath) -> AnyPresentationItemState
    {
        let section = self.sections[indexPath.section]
        let item = section.items[indexPath.item]
        
        return item
    }
    
    func sections(at indexes : [Int]) -> [SectionState]
    {
        var sections : [SectionState] = []
        
        indexes.forEach {
            sections.append(self.sections[$0])
        }
        
        return sections
    }
    
    public var lastIndexPath : IndexPath?
    {
        let nonEmptySections : [(index:Int, section:SectionState)] = self.sections.compactMapWithIndex { index, _, state in
            return state.items.isEmpty ? nil : (index, state)
        }
        
        guard let lastSection = nonEmptySections.last else {
            return nil
        }
        
        return IndexPath(item: (lastSection.section.items.count - 1), section: lastSection.index)
    }
    
    internal func indexPath(for itemToFind : AnyPresentationItemState) -> IndexPath?
    {
        for (sectionIndex, section) in self.sections.enumerated() {
            for (itemIndex, item) in section.items.enumerated() {
                if item === itemToFind {
                    return IndexPath(item: itemIndex, section: sectionIndex)
                }
            }
        }
        
        return nil
    }
    
    internal func forEachItem(_ block : (IndexPath, AnyPresentationItemState) -> ())
    {
        self.sections.forEachWithIndex { sectionIndex, _, section in
            section.items.forEachWithIndex { itemIndex, _, item in
                block(IndexPath(item: itemIndex, section: sectionIndex), item)
            }
        }
    }
    
    //
    // MARK: Mutating Data
    //
    
    func moveItem(from : IndexPath, to : IndexPath)
    {
        guard from != to else {
            return
        }
        
        let item = self.item(at: from)
        
        self.remove(at: from)
        self.insert(item: item, at: to)
    }
    
    @discardableResult
    func remove(at indexPath : IndexPath) -> AnyPresentationItemState
    {
        return self.sections[indexPath.section].items.remove(at: indexPath.item)
    }
    
    func remove(item itemToRemove : AnyPresentationItemState) -> IndexPath?
    {
        guard let indexPath = self.indexPath(for: itemToRemove) else {
            return nil
        }
        
        self.sections[indexPath.section].removeItem(at: indexPath.item)
        
        return indexPath
    }
    
    func insert(item : AnyPresentationItemState, at indexPath : IndexPath)
    {
        self.sections[indexPath.section].insert(item: item, at: indexPath.item)
    }
    
    //
    // MARK: Height Caching
    //
    
    func resetAllCachedHeights()
    {
        self.sections.forEach { section in
            section.items.forEach { item in
                item.resetCachedHeights()
            }
        }
    }
    
    //
    // MARK: Updating Content & State
    //
    
    func update(with diff : SectionedDiff<Section, AnyItem>, slice : Content.Slice)
    {
        self.containsAllItems = slice.containsAllItems
        
        self.contentIdentifier = slice.content.identifier
        
        self.header.state = SectionState.headerFooterState(with: self.header.state, new: slice.content.header)
        self.footer.state = SectionState.headerFooterState(with: self.footer.state, new: slice.content.footer)
        self.overscrollFooter.state = SectionState.headerFooterState(with: self.overscrollFooter.state, new: slice.content.overscrollFooter)
                        
        self.sections = diff.changes.transform(
            old: self.sections,
            removed: { _, _ in },
            added: { section in SectionState(with: section, listView: self.view) },
            moved: { old, new, changes, section in section.update(with: old, new: new, changes: changes, listView: self.view) },
            noChange: { old, new, changes, section in section.update(with: old, new: new, changes: changes, listView: self.view) }
        )
    }
    
    internal func updateRefreshControl(with new : RefreshControl?)
    {
        if let existing = self.refreshControl, let new = new {
            existing.update(with: new)
        } else if self.refreshControl == nil, let new = new {
            let newControl = RefreshControl.PresentationState(new)

            if #available(iOS 10.0, *) {
                self.view.collectionView.refreshControl = newControl.view
            } else {
                self.view.collectionView.addSubview(newControl.view)
            }
            self.refreshControl = newControl
        } else if let existing = refreshControl, new == nil {
            if #available(iOS 10.0, *) {
                self.view.collectionView.refreshControl = nil
            } else {
                existing.view.removeFromSuperview()
            }

            self.refreshControl = nil
        }
    }
    
    //
    // MARK: Cell & Supplementary View Registration
    //
    
    private var registeredCellObjectIdentifiers : Set<ObjectIdentifier> = Set()
    
    func registerCell(for item : AnyPresentationItemState)
    {
        let info = item.cellRegistrationInfo
        
        let identifier = ObjectIdentifier(info.class)
        
        guard self.registeredCellObjectIdentifiers.contains(identifier) == false else {
            return
        }
        
        self.registeredCellObjectIdentifiers.insert(identifier)
        
        self.view.collectionView.register(info.class, forCellWithReuseIdentifier: info.reuseIdentifier)
    }
    
    final class SectionState
    {
        var model : Section
        
        var header : HeaderFooterViewStatePair = .init()
        var footer : HeaderFooterViewStatePair = .init()
        
        var items : [AnyPresentationItemState]
        
        init(with model : Section, listView : ListView)
        {
            self.model = model
            
            self.header.state = SectionState.headerFooterState(with: self.header.state, new: model.header)
            self.footer.state = SectionState.headerFooterState(with: self.footer.state, new: model.footer)
            
            self.items = self.model.items.map {
                $0.newPresentationItemState(in: listView) as! AnyPresentationItemState
            }
        }
        
        fileprivate func removeItem(at index : Int)
        {
            self.model.items.remove(at: index)
            self.items.remove(at: index)
        }
        
        fileprivate func insert(item : AnyPresentationItemState, at index : Int)
        {
            self.model.items.insert(item.anyModel, at: index)
            self.items.insert(item, at: index)
        }
        
        fileprivate func update(
            with oldSection : Section,
            new newSection : Section,
            changes : SectionedDiff<Section, AnyItem>.ItemChanges,
            listView : ListView
            )
        {
            self.model = newSection
            
            self.header.state = SectionState.headerFooterState(with: self.header.state, new: self.model.header)
            self.footer.state = SectionState.headerFooterState(with: self.footer.state, new: self.model.footer)
            
            self.items = changes.transform(
                old: self.items,
                removed: { _, _ in },
                added: { $0.newPresentationItemState(in: listView) as! AnyPresentationItemState },
                moved: { old, new, item in item.setNew(item: new, reason: .move) },
                updated: { old, new, item in item.setNew(item: new, reason: .update) },
                noChange: { old, new, item in item.setNew(item: new, reason: .noChange) }
            )
        }
        
        fileprivate static func headerFooterState(with current : AnyPresentationHeaderFooterState?, new : AnyHeaderFooter?) -> AnyPresentationHeaderFooterState?
        {
            if let current = current {
                if let new = new {
                    let isSameType = type(of: current.anyModel) == type(of: new)
                    
                    if isSameType {
                        current.setNew(headerFooter: new)
                        return current
                    } else {
                        return (new.newPresentationHeaderFooterState() as! AnyPresentationHeaderFooterState)
                    }
                } else {
                    return nil
                }
            } else {
                if let new = new {
                    return (new.newPresentationHeaderFooterState() as! AnyPresentationHeaderFooterState)
                } else {
                    return nil
                }
            }
        }
    }
    
    final class HeaderFooterViewStatePair
    {
        var state : AnyPresentationHeaderFooterState? {
            didSet {
                guard oldValue !== self.state else {
                    return
                }
                
                guard let container = self.visibleContainer else {
                    return
                }
                
                container.headerFooter = self.state
            }
        }
        
        private(set) var visibleContainer : SupplementaryContainerView?
        
        func willDisplay(view : SupplementaryContainerView)
        {
            self.visibleContainer = view
        }
        
        func didEndDisplay()
        {
            self.visibleContainer = nil
        }
        
        func applyToVisibleView()
        {
            guard let view = visibleContainer?.content, let state = self.state else {
                return
            }
            
            state.applyTo(view: view, reason: .wasUpdated)
        }
    }
    
    final class HeaderFooterState<Element:HeaderFooterElement> : AnyPresentationHeaderFooterState
    {
        var model : HeaderFooter<Element>
                
        init(_ model : HeaderFooter<Element>)
        {
            self.model = model            
        }
        
        // MARK: AnyPresentationHeaderFooterState
        
        var anyModel: AnyHeaderFooter {
            return self.model
        }
                
        func dequeueAndPrepareReusableHeaderFooterView(in cache : ReusableViewCache, frame : CGRect) -> UIView
        {
            let view = cache.pop(with: self.model.reuseIdentifier) {
                return Element.Appearance.createReusableHeaderFooterView(frame: frame)
            }
            
            self.applyTo(view: view, reason: .willDisplay)
            
            return view
        }
        
        func enqueueReusableHeaderFooterView(_ view : UIView, in cache : ReusableViewCache)
        {
            cache.push(view, with: self.model.reuseIdentifier)
        }
        
        func createReusableHeaderFooterView(frame : CGRect) -> UIView
        {
            return Element.Appearance.createReusableHeaderFooterView(frame: frame)
        }
        
        func applyTo(view : UIView, reason : ApplyReason)
        {
            let view = view as! Element.Appearance.ContentView
            
            // TODO: Merge this with the other place we apply to views.
            
            self.model.appearance.apply(to: view)
            self.model.element.apply(to: view, reason: reason)
        }
        
        func setNew(headerFooter anyHeaderFooter: AnyHeaderFooter)
        {
            let oldModel = self.model
            
            self.model = anyHeaderFooter as! HeaderFooter<Element>
            
            let reason : UpdateReason = self.model.anyIsEquivalent(to: oldModel) ? .noChange : .update
            
            if oldModel.sizing != self.model.sizing {
                self.resetCachedHeights()
            }
            
            if reason != .noChange {
                self.resetCachedHeights()
            }
        }
        
        private var cachedHeights : [HeightKey:CGFloat] = [:]
        
        func resetCachedHeights()
        {
            self.cachedHeights.removeAll()
        }
        
        func height(width : CGFloat, layoutDirection : LayoutDirection, defaultHeight : CGFloat, measurementCache : ReusableViewCache) -> CGFloat
        {
            guard width > 0.0 else {
                return 0.0
            }
            
            let heightKey = HeightKey(width: width, layoutDirection: layoutDirection)
            
            if let height = self.cachedHeights[heightKey] {
                return height
            } else {
                let height : CGFloat = measurementCache.use(
                    with: self.model.reuseIdentifier,
                    create: {
                        return Element.Appearance.createReusableHeaderFooterView(frame: .zero)
                }, { view in
                    self.model.appearance.apply(to: view)
                    self.model.element.apply(to: view, reason: .willDisplay)
                    
                    return self.model.sizing.measure(with: view, width: width, layoutDirection: layoutDirection, defaultHeight: defaultHeight)
                })
                
                self.cachedHeights[heightKey] = height
                
                return height
            }
        }
    }
    
    final class ItemState<Element:ItemElement> : AnyPresentationItemState
    {
        var model : Item<Element>
        
        let binding : Binding<Element>?
        
        let reorderingActions: ReorderingActions
        
        var itemPosition : ItemPosition
        
        private var visibleCell : ItemElementCell<Element>?
        
        init(with model : Item<Element>, listView : ListView)
        {
            self.model = model
            
            self.reorderingActions = ReorderingActions()
            self.itemPosition = .single
        
            self.cellRegistrationInfo = (ItemElementCell<Element>.self, model.reuseIdentifier.stringValue)
            
            if let binding = self.model.bind?(self.model.element)
            {
                self.binding =  binding
                
                binding.start()
                
                binding.onChange { [weak self] element in
                    guard let self = self else { return }
                    
                    self.model.element = element
                    
                    if let cell = self.visibleCell {
                        let applyInfo = ApplyItemElementInfo(
                            state: .init(cell: cell),
                            position: self.itemPosition,
                            reordering: self.reorderingActions
                        )
                        
                        self.model.element.apply(
                            to: cell.content.contentView,
                            for: .wasUpdated,
                            with: applyInfo
                        )
                    }
                }
                
                // Pull the current element off the binding in case it changed
                // during initialization, from the provider.
                
                self.model.element = binding.element
            } else {
                self.binding = nil
            }
            
            self.reorderingActions.item = self
            self.reorderingActions.listView = listView
        }
        
        deinit {
            self.binding?.discard()
        }
        
        // MARK: AnyPresentationItemState
        
        private(set) var isDisplayed : Bool = false
        
        func setAndPerform(isDisplayed: Bool) {
            guard self.isDisplayed != isDisplayed else {
                return
            }
            
            self.isDisplayed = isDisplayed
            
            if self.isDisplayed {
                self.model.onDisplay?(self.model.element)
            } else {
                self.model.onEndDisplay?(self.model.element)
            }
        }
                
        var anyModel : AnyItem {
            return self.model
        }
        
        var cellRegistrationInfo : (class:AnyClass, reuseIdentifier:String)
        
        func dequeueAndPrepareCollectionViewCell(in collectionView : UICollectionView, for indexPath : IndexPath) -> UICollectionViewCell
        {
            let anyCell = collectionView.dequeueReusableCell(withReuseIdentifier: self.cellRegistrationInfo.reuseIdentifier, for: indexPath)
            
            let cell = anyCell as! ItemElementCell<Element>
            
            // Theme cell & apply content.
            
            let itemState = Listable.ItemState(cell: cell)
            
            self.applyTo(
                cell: cell,
                itemState: itemState,
                reason: .willDisplay
            )
            
            return cell
        }
        
        func applyTo(cell anyCell : UICollectionViewCell, itemState : Listable.ItemState, reason : ApplyReason)
        {
            let cell = anyCell as! ItemElementCell<Element>
            
            let applyInfo = ApplyItemElementInfo(
                state: itemState,
                position: self.itemPosition,
                reordering: self.reorderingActions
            )

            // Appearance
            
            self.model.appearance.apply(
                to: cell.content.contentView,
                with: applyInfo
            )
            
            // Apply Model State
            
            self.model.element.apply(
                to: cell.content.contentView,
                for: reason,
                with: applyInfo
            )

            if
                let actions = self.model.swipeActions,
                let appearance = self.model.swipeActionsAppearance,
                let swipeView = cell.content.swipeView
            {
                cell.content.prepareForSwipeActions(hasActions: true)

                self.model.element.apply(
                    swipe: swipeView,
                    for: reason,
                    with: applyInfo
                )

                appearance.apply(
                    swipeActions: actions,
                    to: swipeView
                )

            } else {
                cell.content.prepareForSwipeActions(hasActions: false)
            }
        }
        
        func applyToVisibleCell()
        {
            guard let cell = self.visibleCell else {
                return
            }
            
            self.applyTo(
                cell: cell,
                itemState: .init(cell: cell),
                reason: .wasUpdated
            )
        }
        
        func setNew(item anyItem: AnyItem, reason: UpdateReason)
        {
            let oldModel = self.model
            
            self.model = anyItem as! Item<Element>
            
            if oldModel.sizing != self.model.sizing {
                self.resetCachedHeights()
            }
            
            if reason != .noChange {
                self.resetCachedHeights()
            }
        }
        
        func willDisplay(cell anyCell : UICollectionViewCell, in collectionView : UICollectionView, for indexPath : IndexPath)
        {
            let cell = (anyCell as! ItemElementCell<Element>)
            
            self.visibleCell = cell
        }
        
        func didEndDisplay()
        {
            self.visibleCell = nil
        }
        
        public func performUserDidSelectItem(isSelected: Bool)
        {
            self.model.selection = .isSelectable(isSelected: isSelected)
            
            if isSelected {
                self.model.onSelect?(self.model.element)
            } else {
                self.model.onDeselect?(self.model.element)
            }
            
            self.applyToVisibleCell()
        }
        
        private var cachedHeights : [HeightKey:CGFloat] = [:]
        
        func resetCachedHeights()
        {
            self.cachedHeights.removeAll()
        }
        
        func height(width : CGFloat, layoutDirection : LayoutDirection, defaultHeight : CGFloat, measurementCache : ReusableViewCache) -> CGFloat
        {
            guard width > 0.0 else {
                return 0.0
            }
            
            let heightKey = HeightKey(width: width, layoutDirection: layoutDirection)
            
            if let height = self.cachedHeights[heightKey] {
                return height
            } else {
                let height : CGFloat = measurementCache.use(
                    with: self.model.reuseIdentifier,
                    create: {
                        return ItemElementCell<Element>()
                }, { cell in
                    let itemState = Listable.ItemState(isSelected: false, isHighlighted: false)
                    
                    self.applyTo(cell: cell, itemState: itemState, reason: .willDisplay)
                    
                    return self.model.sizing.measure(with: cell, width: width, layoutDirection: layoutDirection, defaultHeight: defaultHeight)
                })
                
                self.cachedHeights[heightKey] = height
                
                return height
            }
        }
        
        func moved(with result : Reordering.Result)
        {
            self.model.reordering?.didReorder(result)
        }
    }
}

fileprivate struct HeightKey : Hashable
{
    var width : CGFloat
    var layoutDirection : LayoutDirection
}

