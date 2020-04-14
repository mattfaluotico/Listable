//
//  SwipeController.swift
//  Listable
//
//  Created by Matthew Faluotico on 4/3/20.
//

import Foundation

protocol SwipeControllerDelegate: class {

    func swipeControllerPanDidMove()
    func swipeControllerPanDidEnd()

}

public enum SwipeControllerState {
    case pending
    case swiping(swipeThrough: Bool)
    case locked
    case finished
}

public final class SwipeController<Appearance: ItemElementSwipeActionsAppearance> {

    var state: SwipeControllerState = .pending {
        didSet {
            if let swipeView = self.swipeView {
                appearance.apply(swipeControllerState: state, to: swipeView)
            }
        }
    }

    var actions: SwipeActions

    var appearance: Appearance
    weak var swipeView: Appearance.ContentView?
    weak var contentView: UIView?
    weak var containerView: UIView?
    weak var delegate: SwipeControllerDelegate?

    private weak var collectionView: UICollectionView?

    private(set) var gestureRecognizer: UIPanGestureRecognizer

    init(
        appearance: Appearance,
        actions: SwipeActions,
        contentView: UIView,
        containerView: UIView,
        swipeView: Appearance.ContentView)
    {
        self.appearance = appearance
        self.actions = actions
        self.contentView = contentView
        self.containerView = containerView
        self.gestureRecognizer = UIPanGestureRecognizer()
        self.swipeView = swipeView
    }

    func configure()
    {
        gestureRecognizer.addTarget(self, action: #selector(onPan(_:)))
        containerView?.addGestureRecognizer(gestureRecognizer)
    }

    deinit
    {
        containerView?.removeGestureRecognizer(self.gestureRecognizer)
    }

    func performSwipeThroughAction()
    {
        if let action = actions.actions.first {
            let _ = action.onTap(action)
        }
    }

    // MARK: - Panning

    @objc func onPan(_ pan: UIPanGestureRecognizer)
    {
        switch pan.state {
        case .began:
            guard let collectionView = SwipeController.findCollectionView(child: containerView), self.collectionView == nil else { return }
            collectionView.panGestureRecognizer.addTarget(self, action: #selector(collectionViewPan))
            self.collectionView = collectionView
        case .changed:
            panChanged(pan)
        case .failed, .cancelled, .ended:
            panEnded(pan)
        default:
            break
        }
    }

    private func panChanged(_ pan: UIPanGestureRecognizer)
    {
        let originInContainer = calculateNewOrigin()
        state = panningState(originInContainer: originInContainer)

        delegate?.swipeControllerPanDidMove()
    }

    private func panEnded(_ pan: UIPanGestureRecognizer)
    {
        let originInContainer = calculateNewOrigin()
        state = endState(originInContainer: originInContainer)

        delegate?.swipeControllerPanDidEnd()

        if case .finished = state, swipeThroughEnabled {
            self.performSwipeThroughAction()
        }
    }

    private func panningState(originInContainer: CGPoint) -> SwipeControllerState
    {
        if originInContainer.x > 0 {
            return .pending
        } else
            if originInContainer.x < self.swipeThroughOriginX && self.swipeThroughEnabled {
            return .swiping(swipeThrough: true)
        } else {
            return .swiping(swipeThrough: false)
        }
    }

    private func endState(originInContainer: CGPoint) -> SwipeControllerState
    {
        guard let swipeView = swipeView else { fatalError() }

        let holdXPosition = -appearance.preferredSize(for: swipeView).width

        if originInContainer.x < swipeThroughOriginX && swipeThroughEnabled  {
            return .finished
        } else if originInContainer.x < holdXPosition {
            return .locked
        } else {
            return .pending
        }

    }

    // MARK: - UICollectionView

    @objc func collectionViewPan()
    {
        self.state = .pending
        self.delegate?.swipeControllerPanDidEnd()
        self.collectionView?.panGestureRecognizer.removeTarget(self, action: nil)
        self.collectionView = nil
    }

    // ARK: - Helpers

    func calculateNewOrigin(clearTranslation: Bool = false) -> CGPoint
    {
        guard let containerView = self.containerView, let contentView = self.contentView else {
            return CGPoint.zero
        }

        let translationInContainer: CGPoint = gestureRecognizer.translation(in: containerView)
        let oldPoint = contentView.frame.origin.x

        if clearTranslation {
            gestureRecognizer.setTranslation(.zero, in: containerView)
        }

        return CGPoint(x: oldPoint + translationInContainer.x, y: 0)
    }

    var swipeThroughEnabled: Bool
    {
        return actions.performsFirstOnFullSwipe
    }

    private var swipeThroughOriginX: CGFloat
    {
        guard let containerView = containerView else { fatalError() }
        return -(containerView.bounds.width * 0.6)
    }

    private static func findCollectionView(child: UIView?) -> UICollectionView?
    {
        var view: UIView? = child

        while view != nil {
            if let collectionView = view as? UICollectionView {
                return collectionView
            } else {
                view = view?.superview
            }
        }

        return nil

    }
}

public final class DefaultItemElementSwipeActionsAppearance: ItemElementSwipeActionsAppearance {

    public init() { }

    public static func createView(frame: CGRect) -> SwipeView {
        return .init()
    }

    public func apply(swipeActions: SwipeActions, to view: SwipeView) {
        if let action = swipeActions.actions.first {
            view.action = action
        }
    }

    public func apply(swipeControllerState: SwipeControllerState, to view: DefaultItemElementSwipeActionsAppearance.SwipeView) {
        view.state = swipeControllerState
    }

    public func preferredSize(for view: SwipeView) -> CGSize {
        return view.preferredSize()
    }

    public final class SwipeView: UIView {

        private static var padding: UIEdgeInsets
        {
            return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }

        var state: SwipeControllerState
        {
            didSet {
                UIView.animate(withDuration: 0.2) {
                    switch self.state {
                    case .pending, .swiping(swipeThrough: false), .locked:
                        self.stackView.alignment = .center
                    case .swiping(swipeThrough: true), .finished:
                        self.stackView.alignment = .leading
                    }
                }
            }
        }

        var action: SwipeAction? {
            didSet {
                self.titleView?.text = action?.title
                self.backgroundColor = action?.backgroundColor ?? .white

                if let image = action?.image {
                    if let imageView = self.imageView {
                        imageView.image = image
                    } else {
                        let imageView = UIImageView(image: image)
                        self.stackView.addArrangedSubview(imageView)
                        self.imageView = imageView
                    }
                }
            }
        }

        private var imageView: UIImageView?
        private var titleView: UILabel?
        private var gestureRecognizer: UITapGestureRecognizer
        private var stackView = UIStackView()

        init()
        {
            self.state = .pending
            self.gestureRecognizer = UITapGestureRecognizer()
            super.init(frame: .zero)

            self.gestureRecognizer.addTarget(self, action: #selector(onTap))
            self.addGestureRecognizer(gestureRecognizer)

            let titleView = UILabel()
            titleView.textColor = .white
            titleView.lineBreakMode = .byClipping
            self.stackView.addArrangedSubview(titleView)
            self.titleView = titleView

            stackView.spacing = 2
            stackView.alignment = .center
            stackView.axis = .vertical
            stackView.distribution = .fill
            stackView.isLayoutMarginsRelativeArrangement = true
            stackView.layoutMargins = SwipeView.padding

            self.addSubview(self.stackView)
        }

        required init?(coder: NSCoder)
        {
            fatalError("init(coder:) has not been implemented")
        }

        public override func layoutSubviews()
        {
            super.layoutSubviews()
            self.stackView.frame = self.bounds
        }

        func preferredSize() -> CGSize
        {
            guard let titleView = self.titleView else {
                return self.sizeThatFits(UIScreen.main.bounds.size)
            }

            var size = titleView.sizeThatFits(self.bounds.size)
            size.width += SwipeView.padding.left + SwipeView.padding.right
            return size
        }

        @objc func onTap()
        {
            if let action = self.action {
                let _ = action.onTap(action)
            }
        }
    }
}
