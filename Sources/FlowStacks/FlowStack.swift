import Foundation
import SwiftUI

/// A view that manages state for presenting and pushing screens..
public struct FlowStack<Root: View, Data: Hashable, NavigationViewModifier: ViewModifier>: View {
  var withNavigation: Bool
  var dataType: FlowStackDataType
  var navigationViewModifier: NavigationViewModifier
  @Environment(\.flowStackDataType) var parentFlowStackDataType
  @EnvironmentObject var routesHolder: RoutesHolder
  @EnvironmentObject var inheritedDestinationBuilder: DestinationBuilderHolder
  @Binding var externalTypedPath: [Route<Data>]
  @State var internalTypedPath: [Route<Data>] = []
  @StateObject var path = RoutesHolder()
  @StateObject var destinationBuilder = DestinationBuilderHolder()
  var root: Root
  var useInternalTypedPath: Bool

  var deferToParentFlowStack: Bool {
    parentFlowStackDataType == .flowPath && dataType == .flowPath
  }

  @ViewBuilder
  var content: some View {
    Router(rootView: root, navigationViewModifier: navigationViewModifier, screens: $path.routes)
      .modifier(EmbedModifier(withNavigation: withNavigation, navigationViewModifier: navigationViewModifier))
      .environmentObject(path)
      .environmentObject(Unobserved(object: path))
      .environmentObject(parentFlowStackDataType == nil ? destinationBuilder : inheritedDestinationBuilder)
      .environmentObject(FlowNavigator(useInternalTypedPath ? $internalTypedPath : $externalTypedPath))
      .environment(\.flowStackDataType, dataType)
  }

  public var body: some View {
    if deferToParentFlowStack {
      root
        .onFirstAppear {
          externalTypedPath = routesHolder.routes.map { $0.map { $0 as! Data }}
        }
        .onChange(of: routesHolder.routes) { routes in
          externalTypedPath = routes.map { $0.map { $0 as! Data }}
        }
        .onChange(of: externalTypedPath) { externalTypedPath in
          guard !useInternalTypedPath else { return }
          routesHolder._withDelaysIfUnsupported(\.routes) {
            $0 = externalTypedPath.map { $0.erased() }
          }
        }
    } else {
      content
        .onFirstAppear {
          path._withDelaysIfUnsupported(\.routes) {
            $0 = externalTypedPath.map { $0.erased() }
          }
        }
        .onChange(of: externalTypedPath) { externalTypedPath in
          path._withDelaysIfUnsupported(\.routes) {
            $0 = externalTypedPath.map { $0.erased() }
          }
        }
        .onChange(of: internalTypedPath) { internalTypedPath in
          path._withDelaysIfUnsupported(\.routes) {
            $0 = internalTypedPath.map { $0.erased() }
          }
        }
        .onChange(of: path.routes) { path in
          if useInternalTypedPath {
            guard path != internalTypedPath.map({ $0.erased() }) else { return }
            internalTypedPath = path.compactMap { route in
              if let data = route.screen.base as? Data {
                return route.map { _ in data }
              } else if route.screen.base is LocalDestinationID {
                return nil
              }
              fatalError("Cannot add \(type(of: route.screen.base)) to stack of \(Data.self)")
            }
          } else {
            guard path != externalTypedPath.map({ $0.erased() }) else { return }
            externalTypedPath = path.compactMap { route in
              if let data = route.screen.base as? Data {
                return route.map { _ in data }
              } else if route.screen.base is LocalDestinationID {
                return nil
              }
              fatalError("Cannot add \(type(of: route.screen.base)) to stack of \(Data.self)")
            }
          }
        }
    }
  }

  init(routes: Binding<[Route<Data>]>?, withNavigation: Bool = false, navigationViewModifier: NavigationViewModifier, dataType: FlowStackDataType, @ViewBuilder root: () -> Root) {
    _externalTypedPath = routes ?? .constant([])
    self.root = root()
    self.withNavigation = withNavigation
    self.navigationViewModifier = navigationViewModifier
    self.dataType = dataType
    useInternalTypedPath = routes == nil
  }

  /// Initialises a ``FlowStack`` with a binding to an Array of routes.
  /// - Parameters:
  ///   - routes: The array of routes that will manage navigation state.
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - navigationViewModifier: A modifier for styling any navigation views the FlowStack creates.
  ///   - root: The root view for the ``FlowStack``.
  public init(_ routes: Binding<[Route<Data>]>, withNavigation: Bool = false, navigationViewModifier: NavigationViewModifier, @ViewBuilder root: () -> Root) {
    self.init(routes: routes, withNavigation: withNavigation, navigationViewModifier: navigationViewModifier, dataType: .typedArray, root: root)
  }
}

public extension FlowStack where Data == AnyHashable {
  /// Initialises a ``FlowStack`` without any binding - the stack of routes will be managed internally by the ``FlowStack``.
  /// - Parameters:
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - navigationViewModifier: A modifier for styling any navigation views the FlowStack creates.
  ///   - root: The root view for the ``FlowStack``.
  init(withNavigation: Bool = false, navigationViewModifier: NavigationViewModifier, @ViewBuilder root: () -> Root) {
    self.init(routes: nil, withNavigation: withNavigation, navigationViewModifier: navigationViewModifier, dataType: .flowPath, root: root)
  }

  /// Initialises a ``FlowStack`` with a binding to a ``FlowPath``.
  /// - Parameters:
  ///   - path: The FlowPath that will manage navigation state.
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - navigationViewModifier: A modifier for styling any navigation views the FlowStack creates.
  ///   - root: The root view for the ``FlowStack``.
  init(_ path: Binding<FlowPath>, withNavigation: Bool = false, navigationViewModifier: NavigationViewModifier, @ViewBuilder root: () -> Root) {
    let path = Binding(
      get: { path.wrappedValue.routes },
      set: { path.wrappedValue.routes = $0 }
    )
    self.init(routes: path, withNavigation: withNavigation, navigationViewModifier: navigationViewModifier, dataType: .flowPath, root: root)
  }
}

public extension FlowStack where NavigationViewModifier == UnchangedViewModifier {
  /// Initialises a ``FlowStack`` with a binding to an Array of routes.
  /// - Parameters:
  ///   - routes: The array of routes that will manage navigation state.
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - root: The root view for the ``FlowStack``.
  init(_ routes: Binding<[Route<Data>]>, withNavigation: Bool = false, @ViewBuilder root: () -> Root) {
    self.init(routes: routes, withNavigation: withNavigation, navigationViewModifier: UnchangedViewModifier(), dataType: .typedArray, root: root)
  }
}

public extension FlowStack where NavigationViewModifier == UnchangedViewModifier, Data == AnyHashable {
  /// Initialises a ``FlowStack`` without any binding - the stack of routes will be managed internally by the ``FlowStack``.
  /// - Parameters:
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - root: The root view for the ``FlowStack``.
  init(withNavigation: Bool = false, @ViewBuilder root: () -> Root) {
    self.init(withNavigation: withNavigation, navigationViewModifier: UnchangedViewModifier(), root: root)
  }

  /// Initialises a ``FlowStack`` with a binding to a ``FlowPath``.
  /// - Parameters:
  ///   - path: The FlowPath that will manage navigation state.
  ///   - withNavigation: Whether the root view should be wrapped in a navigation view.
  ///   - root: The root view for the ``FlowStack``.
  init(_ path: Binding<FlowPath>, withNavigation: Bool = false, @ViewBuilder root: () -> Root) {
    self.init(path, withNavigation: withNavigation, navigationViewModifier: UnchangedViewModifier(), root: root)
  }
}
