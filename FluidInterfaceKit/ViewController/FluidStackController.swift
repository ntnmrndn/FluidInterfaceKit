import UIKit
import SwiftUI

/**
 A container view controller that manages view controller and view as child view controllers.
 It provides transitions when adding and removing.

 You may create subclass of this to make a first view.
 */
open class FluidStackController: UIViewController {

  private final class WrapperView: UIView {

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
      let view = super.hitTest(point, with: event)
      if view == self {
        return nil
      } else {
        return view
      }
    }

  }

  private final class RootContentView: UIView {
  }

  private struct State: Equatable {

  }

  private var state: State = .init()
  private let __rootView: UIView?

  public let contentView: UIView
  public var stackingViewControllers: [ViewControllerFluidContentType] = []

  final class ViewControllerStateToken: Equatable {

    static func == (lhs: FluidStackController.ViewControllerStateToken, rhs: FluidStackController.ViewControllerStateToken) -> Bool {
      lhs === rhs
    }

    let state: ViewControllerState

    init(state: ViewControllerState) {
      self.state = state
    }
  }

  enum ViewControllerState: Int {
    case removed
    case adding
    case added
    case removing
  }

  private var viewControllerStateMap: NSMapTable<UIViewController, TransitionContext> =
    .weakToStrongObjects()

  open override func loadView() {
    if let __rootView = __rootView {
      view = __rootView
    } else {
      super.loadView()
    }
  }

  public init(
    view: UIView? = nil
  ) {
    self.__rootView = view
    self.contentView = RootContentView()
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  public required init?(
    coder: NSCoder
  ) {
    fatalError("init(coder:) has not been implemented")
  }

  open override func viewDidLoad() {
    super.viewDidLoad()

    view.addSubview(contentView)
    contentView.frame = view.bounds
    contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
  }

  public func addContentView(_ view: UIView, transition: AnyAddingTransition?) {

    assert(Thread.isMainThread)

    let viewController = AnonymousViewController(view: view)
    addContentViewController(viewController, transition: transition)

  }

  public func removeLastViewController(transition: AnyRemovingTransition?) {

    assert(Thread.isMainThread)

    guard let viewControllerToRemove = stackingViewControllers.last else {
      Log.error(.zStack, "The last view controller was not found to remove")
      return
    }

    removeViewController(viewControllerToRemove, transition: transition)

    viewControllerToRemove.fluidStackControllerContext = nil
  }

  /**
   Displays a view controller

   - Parameters:
     - transition: a transition for adding. if view controller is type of ``TransitionViewController``, uses this transition instead of TransitionViewController's transition.
   */
  public func addContentViewController(
    _ viewControllerToAdd: ViewControllerFluidContentType,
    transition: AnyAddingTransition?
  ) {

    /**
     possible to enter while previous adding operation.
     adding -> removing(interruption) -> adding(interruption) -> dipslay(completed)
     */

    assert(Thread.isMainThread)

    let backViewController = stackingViewControllers.last
    stackingViewControllers.removeAll { $0 == viewControllerToAdd }
    stackingViewControllers.append(viewControllerToAdd)

    if viewControllerToAdd.fluidStackControllerContext == nil {
      /// set context
      viewControllerToAdd.fluidStackControllerContext = .init(
        FluidStackController: self,
        targetViewController: viewControllerToAdd
      )
    }

    if viewControllerToAdd.parent != self {
      addChild(viewControllerToAdd)

      let containerView = WrapperView()
      containerView.backgroundColor = .clear

      containerView.addSubview(viewControllerToAdd.view)
      containerView.frame = self.view.bounds
      containerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

      viewControllerToAdd.view.transform = .identity
      viewControllerToAdd.view.frame = self.view.bounds
      viewControllerToAdd.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

      view.addSubview(containerView)

      viewControllerToAdd.didMove(toParent: self)
    } else {
      // TODO: something needed
    }

    let transitionContext = AddingTransitionContext(
      contentView: viewControllerToAdd.view.superview!,
      fromViewController: backViewController,
      toViewController: viewControllerToAdd,
      onCompleted: { [weak self] context in

        guard let self = self else { return }

        guard context.isInvalidated == false else {
          Log.debug(.zStack, "\(context) was invalidated, skips adding")
          return
        }

        self.setViewControllerState(viewController: viewControllerToAdd, context: nil)
        context.transitionFinished()

      }
    )

    viewControllerState(viewController: viewControllerToAdd)?.invalidate()
    setViewControllerState(viewController: viewControllerToAdd, context: transitionContext)

    if let transition = transition {

      transition.startTransition(context: transitionContext)
    } else if let transitionViewController = viewControllerToAdd as? TransitionViewController {

      transitionViewController.startAddingTransition(
        context: transitionContext
      )
    } else {
      transitionContext.notifyCompleted()
    }

  }

  /**
   Starts removing transaction.
   Make sure to complete the transition with the context.
   */
  public func startRemoving(_ viewControllerToRemove: ViewControllerFluidContentType) -> RemovingTransitionContext {

    guard let index = stackingViewControllers.firstIndex(where: { $0 == viewControllerToRemove}) else {
      Log.error(.zStack, "\(viewControllerToRemove) was not found to remove")
      fatalError()
    }

    let backViewController: UIViewController? = {
      let target = index.advanced(by: -1)
      if stackingViewControllers.indices.contains(target) {
        return stackingViewControllers[target]
      } else {
        return nil
      }
    }()

    let transitionContext = RemovingTransitionContext(
      contentView: viewControllerToRemove.view.superview!,
      fromViewController: viewControllerToRemove,
      toViewController: backViewController,
      onCompleted: { [weak self] context in

        guard let self = self else { return }

        guard context.isInvalidated == false else {
          Log.debug(.zStack, "\(context) was invalidated, skips removing")
          return
        }

        /**
         Completion of transition, cleaning up
         */

        self.setViewControllerState(viewController: viewControllerToRemove, context: nil)

        self.stackingViewControllers.removeAll { $0 == viewControllerToRemove }
        viewControllerToRemove.fluidStackControllerContext = nil

        viewControllerToRemove.willMove(toParent: nil)
        viewControllerToRemove.view.superview!.removeFromSuperview()
        viewControllerToRemove.removeFromParent()

        context.transitionFinished()

      }
    )

    viewControllerState(viewController: viewControllerToRemove)?.invalidate()
    setViewControllerState(viewController: viewControllerToRemove, context: transitionContext)

    return transitionContext
  }

  public func removeViewController(
    _ viewControllerToRemove: ViewControllerFluidContentType,
    transition: AnyRemovingTransition?
  ) {

    let transitionContext = startRemoving(viewControllerToRemove)

    if let transition = transition {
      transition.startTransition(context: transitionContext)
    } else if let transitionViewController = viewControllerToRemove as? TransitionViewController {
      transitionViewController.startRemovingTransition(context: transitionContext)
    } else {
      transitionContext.notifyCompleted()
    }

  }

  public func removeAllViewController(transition: AnyBatchRemovingTransition?) {
    guard let first = stackingViewControllers.first else { return }
    removeAllViewController(from: first, transition: transition)
  }

  // FIXME: not completed implementation
  public func removeAllViewController(
    from viewController: UIViewController,
    transition: AnyBatchRemovingTransition?
  ) {

    Log.debug(.zStack, "Remove \(viewController) from \(stackingViewControllers)")

    assert(Thread.isMainThread)

    guard let index = stackingViewControllers.firstIndex(where: { $0 == viewController}) else {
      Log.error(.zStack, "\(viewController) was not found to remove")
      return
    }

    let targetTopViewController: UIViewController? = stackingViewControllers[0..<(index)].last

    let viewControllersToRemove = Array(
      stackingViewControllers[
        index...stackingViewControllers.indices.last!
      ]
    )

    assert(viewControllersToRemove.count > 0)

    if let transition = transition {

      viewControllersToRemove.forEach {
        $0.willMove(toParent: nil)
        $0.removeFromParent()
      }

      let transitionContext = BatchRemovingTransitionContext(
        contentView: viewControllersToRemove.first!.view.superview!,
        fromViewControllers: viewControllersToRemove,
        toViewController: targetTopViewController,
        onCompleted: { [weak self] context in

          guard let self = self else { return }

          /**
           Completion of transition, cleaning up
           */

          for viewControllerToRemove in viewControllersToRemove where context.isInvalidated(for: viewControllerToRemove) == false {
            self.setViewControllerState(viewController: viewControllerToRemove, context: nil)
            viewControllerToRemove.willMove(toParent: nil)
            viewControllerToRemove.view.superview!.removeFromSuperview()
            viewControllerToRemove.removeFromParent()
            viewControllerToRemove.fluidStackControllerContext = nil
          }

          self.stackingViewControllers.removeAll { instance in viewControllersToRemove.contains(where: { $0 == instance }) }

          context.transitionFinished()

        }
      )

      for viewControllerToRemove in viewControllersToRemove {
        viewControllerState(viewController: viewControllerToRemove)?.invalidate()
        setViewControllerState(viewController: viewControllerToRemove, context: transitionContext.child(for: viewControllerToRemove))
      }

      transition.startTransition(context: transitionContext)

    } else {

      while stackingViewControllers.last != targetTopViewController {

        let viewControllerToRemove = stackingViewControllers.last!
        viewControllerState(viewController: viewControllerToRemove)?.invalidate()
        setViewControllerState(viewController: viewControllerToRemove, context: nil)

        assert(stackingViewControllers.last === viewControllerToRemove)

        viewControllerToRemove.willMove(toParent: nil)
        viewControllerToRemove.view.removeFromSuperview()
        viewControllerToRemove.removeFromParent()

        stackingViewControllers.removeLast()

      }

    }

    Log.debug(.zStack, "Removed => \(children)")

  }

  private func setViewControllerState(viewController: UIViewController, context: TransitionContext?)
  {
    viewControllerStateMap.setObject(context, forKey: viewController)
  }

  private func viewControllerState(viewController: UIViewController) -> TransitionContext? {
    viewControllerStateMap.object(forKey: viewController)
  }
 
}

public struct FluidStackControllerContext {

  public private(set) weak var FluidStackController: FluidStackController?
  public private(set) weak var targetViewController: ViewControllerFluidContentType?

  /**
   Adds view controller to parent container if it presents.
   */
  public func addContentViewController(
    _ viewController: ViewControllerFluidContentType,
    transition: AnyAddingTransition?
  ) {
    FluidStackController?.addContentViewController(viewController, transition: transition)
  }

  public func addContentView(_ view: UIView, transition: AnyAddingTransition?) {
    FluidStackController?.addContentView(view, transition: transition)
  }

  /// Removes the target view controller in ``FluidStackController``.
  /// - Parameter transition: if not nil, it would be used override parameter.
  public func removeSelf(transition: AnyRemovingTransition?) {
    guard let targetViewController = targetViewController else {
      return
    }
    FluidStackController?.removeViewController(targetViewController, transition: transition)
  }

  /**
   Starts transition for removing if parent container presents.
   */
  public func startRemoving() -> RemovingTransitionContext? {
    guard let targetViewController = targetViewController else {
      return nil
    }
    return FluidStackController?.startRemoving(targetViewController)
  }

  public func removeAllViewController(transition: AnyBatchRemovingTransition?) {
    FluidStackController?.removeAllViewController(transition: transition)
  }

}

public protocol ViewControllerFluidContentType: UIViewController {
  var fluidStackControllerContext: FluidStackControllerContext? { get }
}

var ref: Void?

extension ViewControllerFluidContentType {

  public internal(set) var fluidStackControllerContext: FluidStackControllerContext? {
    get {

      guard let object = objc_getAssociatedObject(self, &ref) as? FluidStackControllerContext else {

        guard let compatibleParent = parent as? ViewControllerFluidContentType else {
          return nil
        }
        return compatibleParent.fluidStackControllerContext
      }
      return object

    }
    set {

      objc_setAssociatedObject(
        self,
        &ref,
        newValue,
        .OBJC_ASSOCIATION_RETAIN_NONATOMIC
      )

    }

  }
}

private final class AnonymousViewController: UIViewController, ViewControllerFluidContentType {

  private let __rootView: UIView

  override func loadView() {
    view = __rootView
  }

  init(
    view: UIView
  ) {
    self.__rootView = view
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  public required init?(
    coder: NSCoder
  ) {
    fatalError("init(coder:) has not been implemented")
  }
}