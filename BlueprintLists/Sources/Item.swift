//
//  Item.swift
//  BlueprintLists
//
//  Created by Kyle Van Essen on 10/22/19.
//

import BlueprintUI

import Listable


//
// MARK: Blueprint Elements
//

public protocol BlueprintItemElement : ItemElement where
    Appearance == BlueprintItemElementAppearance,
    SwipeActionsAppearance == BlueprintItemElementSwipeActionsAppearance
{
    //
    // MARK: Creating Blueprint Element Representations (Required)
    //
    
    func element(with info : ApplyItemElementInfo) -> BlueprintUI.Element

    func swipeElement(with info : ApplyItemElementInfo) -> BlueprintUI.Element?
}

/// Default nil Swipe  Actions
public extension BlueprintItemElement {

    func swipeElement(with info: ApplyItemElementInfo) -> Element? {
        return nil
    }

}

//
// MARK: Creating Blueprint Items
//


public extension Listable.Item where Element : BlueprintItemElement
{
    init(
        _ element : Element,
        build : Build
        )
    {
        self.init(with: element)
        
        build(&self)
    }
    
    init(
        with element : Element,
        sizing : Sizing = .thatFitsWith(.atLeast(.default)),
        layout : ItemLayout = ItemLayout(),
        selection : ItemSelection = .notSelectable,
        swipeActions : SwipeActions? = nil,
        reordering : Reordering? = nil,
        bind : CreateBinding? = nil,
        onDisplay : OnDisplay? = nil,
        onSelect : OnSelect? = nil,
        onDeselect : OnDeselect? = nil
        )
    {
        self.init(
            with: element,
            appearance: BlueprintItemElementAppearance(),
            sizing: sizing,
            layout: layout,
            selection: selection,
            swipeActions: swipeActions,
            swipeActionsAppearance: BlueprintItemElementSwipeActionsAppearance(),
            reordering: reordering,
            bind: bind,
            onDisplay: onDisplay,
            onSelect: onSelect,
            onDeselect: onDeselect
        )
    }
}

//
// MARK: Applying Blueprint Elements
//

public extension BlueprintItemElement
{
    //
    // MARK: ItemElement
    //
    
    func apply(to view : Appearance.ContentView, for reason: ApplyReason, with info : ApplyItemElementInfo)
    {
        view.element = self.element(with: info)
    }

    func apply(swipe view: SwipeActionsAppearance.ActionContentView, for reason: ApplyReason, with info: ApplyItemElementInfo) {
        view.element = self.swipeElement(with: info)
    }
}


public struct BlueprintItemElementAppearance : ItemElementAppearance
{
    //
    // MARK: ItemElementAppearance
    //
    
    public typealias ContentView = BlueprintView
    
    public static func createReusableItemView(frame: CGRect) -> ContentView
    {
        let view = BlueprintView(frame: frame)
        view.backgroundColor = .clear
        
        return view
    }
    
    public func update(view: BlueprintView, with position: ItemPosition) {}
    
    public func apply(to view: BlueprintView, with info: ApplyItemElementInfo) {}

    public func isEquivalent(to other: BlueprintItemElementAppearance) -> Bool
    {
        return true
    }
}

public struct BlueprintItemElementSwipeActionsAppearance : ItemElementSwipeActionsAppearance
{
    public typealias ContentView = BlueprintView

    public static func createView(frame: CGRect) -> BlueprintView {
        let view = BlueprintView(frame: frame)
        view.backgroundColor = .clear

        return view
    }

    public func apply(swipeActions: SwipeActions, to view: BlueprintView) { }

    public func isEquivalent(to other: BlueprintItemElementSwipeActionsAppearance) -> Bool
    {
        return true
    }
}
