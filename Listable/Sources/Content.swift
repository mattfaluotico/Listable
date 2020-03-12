//
//  Elements.swift
//  Listable
//
//  Created by Kyle Van Essen on 6/21/19.
//



public struct Content
{
    //
    // MARK: Content Data
    //
    
    public var identifier : AnyHashable?
    
    public var selectionMode : SelectionMode
    
    public enum SelectionMode : Equatable
    {
        case none, single, multiple
    }

    public var refreshControl : RefreshControl?
    
    public var header : AnyHeaderFooter?
    public var footer : AnyHeaderFooter?
    
    public var overscrollFooter : AnyHeaderFooter?
    
    public var sections : [Section]
    
    public var itemCount : Int {
        return self.sections.reduce(0, { $0 + $1.items.count })
    }
    
    public var isEmpty : Bool {
        return self.sections.isEmpty || self.sections.allSatisfy { $0.isEmpty }
    }
    
    //
    // MARK: Initialization
    //
    
    public typealias Build = (inout Content) -> ()
    
    public init(with build : Build)
    {
        self.init()
        
        build(&self)
    }
    
    public init(
        identifier : AnyHashable? = nil,
        selectionMode : SelectionMode = .single,
        refreshControl : RefreshControl? = nil,
        header : AnyHeaderFooter? = nil,
        footer : AnyHeaderFooter? = nil,
        overscrollFooter : AnyHeaderFooter? = nil,
        sections : [Section] = []
        )
    {
        self.identifier = identifier
        
        self.selectionMode = selectionMode
        
        self.refreshControl = refreshControl
        
        self.header = header
        self.footer = footer
        
        self.overscrollFooter = overscrollFooter
        
        self.sections = sections
    }
    
    //
    // MARK: Finding Content
    //
    
    public func item(at indexPath : IndexPath) -> AnyItem
    {
        let section = self.sections[indexPath.section]
        let item = section.items[indexPath.item]
        
        return item
    }
    
    public func indexPath(for identifier : AnyIdentifier) -> IndexPath?
    {
        for (sectionIndex, section) in self.sections.enumerated() {
            for (itemIndex, item) in section.items.enumerated() {
                if item.identifier == identifier {
                    return IndexPath(item: itemIndex, section: sectionIndex)
                }
            }
        }
        
        return nil
    }

    public func lastIndexPath() -> IndexPath?
    {
        guard let lastSectionIndexWithItems = sections.lastIndex(where: { !$0.items.isEmpty }) else {
            return nil
        }

        return IndexPath(
            item: sections[lastSectionIndexWithItems].items.count,
            section: lastSectionIndexWithItems
        )
    }
    
    //
    // MARK: Mutating Content
    //
    
    mutating func moveItem(from : IndexPath, to : IndexPath)
    {
        guard from != to else {
            return
        }
        
        let item = self.item(at: from)
        
        self.remove(at: from)
        self.insert(item: item, at: to)
    }
    
    public mutating func removeEmpty()
    {
        self.sections.removeAll {
            $0.items.isEmpty
        }
    }
    
    public mutating func add(_ section : Section)
    {
        self.sections.append(section)
    }
    
    public static func += (lhs : inout Content, rhs : Section)
    {
        lhs.add(rhs)
    }
    
    public static func += (lhs : inout Content, rhs : [Section])
    {
        lhs.sections += rhs
    }
    
    internal mutating func remove(at indexPath : IndexPath)
    {
        self.sections[indexPath.section].items.remove(at: indexPath.item)
    }
    
    internal mutating func insert(item : AnyItem, at indexPath : IndexPath)
    {
        self.sections[indexPath.section].items.insert(item, at: indexPath.item)
    }
    
    //
    // MARK: Slicing Content
    //
    
    internal func sliceTo(indexPath : IndexPath, plus additionalItems : Int) -> Slice
    {
        var sliced = self
        
        var remaining : Int = indexPath.item + additionalItems
        
        sliced.sections = self.sections.compactMapWithIndex { sectionIndex, _, section in
            if sectionIndex < indexPath.section {
                return section
            } else {
                guard remaining > 0 else {
                    return nil
                }
                
                var section = section
                section.items = section.itemsUpTo(limit: remaining)
                remaining -= section.items.count
                
                return section
            }
        }
        
        return Slice(
            containsAllItems: self.itemCount == sliced.itemCount,
            content: sliced
        )
    }
}


public extension Content
{
    func elementsEqual(to other : Content) -> Bool
    {
        if self.sections.count != other.sections.count {
            return false
        }
        
        let sections = zip(self.sections, other.sections)
        
        return sections.allSatisfy { both in
            both.0.elementsEqual(to: both.1)
        }
    }
}


internal extension Content
{
    struct Slice
    {
        static let defaultSize : Int = 250
        
        let containsAllItems : Bool
        let content : Content
        
        init(containsAllItems : Bool, content : Content)
        {
            self.containsAllItems = containsAllItems
            self.content = content
        }
        
        init()
        {
            self.containsAllItems = true
            self.content = Content()
        }
        
        enum UpdateReason : Equatable
        {
            case scrolledDown
            case didEndDecelerating
            
            case scrolledToTop
            
            case contentChanged(animated : Bool, identifierChanged : Bool)
            
            case transitionedToBounds(isEmpty : Bool)
            
            case programaticScrollDownTo(IndexPath)
        
            var animated : Bool {
                switch self {
                case .scrolledDown: return false
                case .didEndDecelerating: return false
                case .scrolledToTop: return false
                    
                case .contentChanged(let animated, let identifierChanged): return animated && identifierChanged == false
                    
                case .transitionedToBounds(_): return false
                    
                case .programaticScrollDownTo(_): return false
                }
            }
        }
    }
}
