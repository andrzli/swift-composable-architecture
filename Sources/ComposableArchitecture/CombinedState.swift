@dynamicMemberLookup
public struct CombinedState<SharedState, PrivateState> {
  var shared: SharedState
  var `private`: PrivateState

  subscript<T>(dynamicMember keyPath: WritableKeyPath<PrivateState, T>) -> T {
    get { self.private[keyPath: keyPath] }
    set { self.private[keyPath: keyPath] = newValue }
  }

  subscript<T>(dynamicMember keyPath: WritableKeyPath<SharedState, T>) -> T {
    get { self.shared[keyPath: keyPath] }
    set { self.shared[keyPath: keyPath] = newValue }
  }
}

extension CombinedState: Equatable where SharedState: Equatable, PrivateState: Equatable {}
