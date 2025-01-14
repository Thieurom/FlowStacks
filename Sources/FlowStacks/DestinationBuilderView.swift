import Foundation
import SwiftUI

/// Builds a view from the given Data, using the destination builder environment object.
struct DestinationBuilderView: View {
  let data: Binding<AnyHashable>

  @EnvironmentObject var destinationBuilder: DestinationBuilderHolder

  var body: some View {
    destinationBuilder.build(data)
  }
}
