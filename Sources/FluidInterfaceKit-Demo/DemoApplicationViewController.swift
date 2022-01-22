import CompositionKit
import FluidInterfaceKit
import MondrianLayout
import UIKit
import ResultBuilderKit

final class DemoApplicationController: FluidStackController {

  override func viewDidLoad() {
    super.viewDidLoad()

    addContentViewController(AppTabBarController(), transition: .noAnimation)
  }

}

final class AppTabBarController: UITabBarController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    viewControllers = [
      UINavigationController(rootViewController: AppSearchViewController()),
      UINavigationController(rootViewController: AppOtherController()),
    ]

    tabBar.backgroundColor = .black
  }

}

final class AppSearchViewController: FluidStackController {

  init() {
    super.init()
    title = "Search"
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .neon(.cyan)

    let list = VGridView(numberOfColumns: 1)

    Mondrian.buildSubviews(on: view) {
      ZStackBlock(alignment: .attach(.all)) {
        list
          .viewBlock
      }
      .container(respectingSafeAreaEdges: .all)
    }

    list.setContents(
      buildArray {

        makeButtonView(
          title: "Open",
          onTap: { [unowned self] in

            let controller = AppOptionsController()

            rootFluidStackController()?.addContentViewController(controller, transition: .modalIdiom())

          }
        )

      }
    )

  }

}

final class AppOptionsController: CodeBasedViewController {

  override init() {
    super.init()
    title = "Options"
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .neon(.red)

    let list = VGridView(numberOfColumns: 1)

    Mondrian.buildSubviews(on: view) {
      ZStackBlock(alignment: .attach(.all)) {
        list
          .viewBlock
      }
      .container(respectingSafeAreaEdges: .all)
    }

    list.setContents(
      buildArray {

        makeButtonView(
          title: "Dismiss",
          onTap: { [unowned self] in

            fluidStackContext?.removeSelf(transition: nil)

          }
        )

        makeButtonView(
          title: "Open",
          onTap: { [unowned self] in

            let controller = AppOptionsController()

            fluidStackContext?.addContentViewController(controller, transition: .modalIdiom())

          }
        )

      }
    )
  }
}


final class AppOtherController: CodeBasedViewController {

  override init() {
    super.init()
    title = "Other"
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = .neon(.blue)
  }
}