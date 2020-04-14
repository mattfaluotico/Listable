//
//  ItemCellView.swift
//  Listable
//
//  Created by Kyle Van Essen on 3/23/20.
//

import UIKit


extension ItemElementCell
{
    final class ContentView : UIView, SwipeControllerDelegate
    {
        private(set) var contentView : Element.Appearance.ContentView

        private var swipeController: SwipeController<Element.SwipeActionsAppearance>?
        private var swipeView : Element.SwipeActionsAppearance.ContentView?

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

            if let swipeController = self.swipeController, let swipeView = self.swipeView {
                self.setFrames(swipeController: swipeController, swipeView: swipeView)
            } else {
                contentView.frame = self.bounds
            }
        }

        /// Set frames when swipe controller is active
        private func setFrames(swipeController: SwipeController<Element.SwipeActionsAppearance>, swipeView: Element.SwipeActionsAppearance.ContentView)
        {
            let newOrigin_x: CGFloat

            switch swipeController.state {
            case .pending:
                newOrigin_x = 0

            case .locked:
                // MFTODO flip
                let lowerThreshold = swipeController.appearance.preferredSize(for: swipeView).width
                newOrigin_x = -lowerThreshold

            case .finished:
                let end = self.bounds.width
                newOrigin_x = -end

            case .swiping(swipeThrough: _):
                newOrigin_x = swipeController.calculateNewOrigin(clearTranslation: true).x
            }

            let width = self.bounds.width
            var frame = self.contentView.frame
            frame.origin.x = newOrigin_x
            self.contentView.frame = frame

            let originX = frame.maxX
            let swipeWidth = width - originX

            self.swipeView?.frame = CGRect(
                x: originX,
                y: frame.origin.y,
                width: swipeWidth,
                height: frame.height
            )
        }

        // MARK: - Swipe Registration

        public func deregisterSwipeIfNeeded()
        {
            guard swipeController != nil else { return }

            swipeController = nil
            swipeView?.removeFromSuperview()
            swipeView = nil
        }

        public func registerSwipeActionsIfNeeded(actions: SwipeActions, appearance: Element.SwipeActionsAppearance)
        {
            guard self.swipeController == nil else { return } // Already Registered

            let swipeView = Element.SwipeActionsAppearance.createView(frame: .zero)

            let swipeController = SwipeController<Element.SwipeActionsAppearance>(
                appearance: appearance,
                actions: actions,
                contentView: self.contentView,
                containerView: self,
                swipeView: swipeView
            )

            swipeController.configure()
            swipeController.delegate = self

            self.insertSubview(swipeView, belowSubview: self.contentView)

            self.swipeController = swipeController
            self.swipeView = swipeView

            self.setNeedsLayout()
            self.layoutIfNeeded()
        }

        // MARK: - Swipe Controller Delegate

        func swipeControllerPanDidMove()
        {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }

        func swipeControllerPanDidEnd()
        {
            UIView.animate(withDuration: 0.2) {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }
        }
    }
}

