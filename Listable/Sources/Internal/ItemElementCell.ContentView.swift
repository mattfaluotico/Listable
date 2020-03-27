//
//  ItemCellView.swift
//  Listable
//
//  Created by Kyle Van Essen on 3/23/20.
//

import UIKit


extension ItemElementCell
{
    final class ContentView : UIView, UIGestureRecognizerDelegate
    {
        private(set) var contentView : Element.Appearance.ContentView

        lazy private(set) var swipeView : Element.SwipeActionsAppearance.ContentView
            = Element.SwipeActionsAppearance.createView(frame: self.frame)

        private var panGesture: UIPanGestureRecognizer?

        override init(frame : CGRect)
        {
            let bounds = CGRect(origin: .zero, size: frame.size)
            
            self.contentView = Element.Appearance.createReusableItemView(frame: bounds)

            super.init(frame: frame)
            
            self.addSubview(self.contentView)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }
        
        override func layoutSubviews()
        {
            super.layoutSubviews()
            
            self.contentView.frame = self.bounds
        }

        // MARK: - Swipe

        public func prepareForSwipeActions(hasActions: Bool) {
            if hasActions {
                let panGesture = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(onPan(_:))
                )
                panGesture.delegate = self
                self.panGesture = panGesture
                self.addGestureRecognizer(panGesture)
            } else if let panGesture = panGesture {
                panGesture.removeTarget(self, action: #selector(onPan(_:)))
                removeGestureRecognizer(panGesture)
                self.panGesture = nil
            }
        }

        @objc func onPan(_ pan: UIPanGestureRecognizer) {
            print("ya boi is pannin'")
        }
    }
}
