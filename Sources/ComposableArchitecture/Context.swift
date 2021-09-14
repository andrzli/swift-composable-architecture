//@dynamicMemberLookup
public class ContextHandle<Context> {
  @Published public var context: Context

//  public subscript<T>(dynamicMember keyPath: WritableKeyPath<Context, T>) -> T {
//    get { self.context[keyPath: keyPath] }
//    set { self.context[keyPath: keyPath] = newValue }
//  }

  public init(_ context: Context) {
    self.context = context
  }
}
