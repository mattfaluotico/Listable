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

        private(set) var swipeView : Element.SwipeActionsAppearance.ActionContentView?

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
            
            // Update view to the state of the pan gesture
            if
                let panGesture = panGesture,
                panGesture.state == UIGestureRecognizer.State.changed,
                let swipeView = swipeView
            {
                let pointInSelf: CGPoint = panGesture.translation(in: self)
                var newFrame = self.contentView.bounds
                newFrame.origin = CGPoint(x: pointInSelf.x, y: 0)
                self.contentView.frame = newFrame
                swipeView.frame = self.bounds

            } else {
                contentView.frame = self.bounds
            }

        }

        // MARK: - Swipe

        public func prepareForSwipeActions(hasActions: Bool)
        {
            if hasActions {
                let panGesture = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(onPan(_:))
                )
                panGesture.delegate = self
                addGestureRecognizer(panGesture)
                self.panGesture = panGesture

                let swipeView = Element.SwipeActionsAppearance.createView(frame: self.frame)
                self.insertSubview(swipeView, belowSubview: self.contentView)
                self.swipeView = swipeView

            } else if let panGesture = panGesture {

                panGesture.removeTarget(self, action: #selector(onPan(_:)))
                removeGestureRecognizer(panGesture)
                self.panGesture = nil

                swipeView?.removeFromSuperview()
                swipeView = nil
            }
        }

        @objc func onPan(_ pan: UIPanGestureRecognizer)
        {
            if pan.state == UIGestureRecognizer.State.began {
                // no op, we could build the backing view here instead
            } else if pan.state == UIGestureRecognizer.State.changed {
                self.setNeedsLayout()
            } else {
                // Animate back into place (temporary)
                UIView.animate(withDuration: 0.1, animations: {
                    self.setNeedsLayout()
                    self.layoutIfNeeded()
                })

                // TODO check for threshold to swipe away and send message to delegate
            }
        }
    }
}
