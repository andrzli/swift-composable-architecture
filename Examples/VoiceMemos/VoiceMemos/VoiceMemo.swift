import ComposableArchitecture
import Foundation
import SwiftUI

struct VoiceMemo: Equatable, Identifiable {
  var date: Date
  var duration: TimeInterval
  var mode = Mode.notPlaying
  var title = ""
  var url: URL

  var id: URL { self.url }

  enum Mode: Equatable {
    case notPlaying
    case playing(progress: Double)

    var isPlaying: Bool {
      if case .playing = self { return true }
      return false
    }

    var progress: Double? {
      if case let .playing(progress) = self { return progress }
      return nil
    }
  }
}

enum VoiceMemoAction: Equatable {
  case audioPlayerClient(Result<AudioPlayerClient.Action, AudioPlayerClient.Failure>)
  case playButtonTapped
  case delete
  case timerUpdated(TimeInterval)
  case titleTextFieldChanged(String)
}

struct VoiceMemoEnvironment {
  var audioPlayerClient: AudioPlayerClient
  var mainRunLoop: AnySchedulerOf<RunLoop>
}

let voiceMemoReducer = Reducer<VoiceMemo, VoiceMemoAction, VoiceMemoEnvironment> {
  memo, action, environment in
  struct PlayerId: Hashable {}
  struct TimerId: Hashable {}

  switch action {
  case .audioPlayerClient(.success(.didFinishPlaying)), .audioPlayerClient(.failure):
    memo.mode = .notPlaying
    return .cancel(id: TimerId())

  case .delete:
    return .merge(
      environment.audioPlayerClient
        .stop(PlayerId())
        .fireAndForget(),
      .cancel(id: PlayerId()),
      .cancel(id: TimerId())
    )

  case .playButtonTapped:
    switch memo.mode {
    case .notPlaying:
      memo.mode = .playing(progress: 0)
      let start = environment.mainRunLoop.now
      return .merge(
        Effect.timer(id: TimerId(), every: 0.5, on: environment.mainRunLoop)
          .map { .timerUpdated($0.date.timeIntervalSince1970 - start.date.timeIntervalSince1970) },

        environment.audioPlayerClient
          .play(PlayerId(), memo.url)
          .catchToEffect(VoiceMemoAction.audioPlayerClient)
          .cancellable(id: PlayerId())
      )

    case .playing:
      memo.mode = .notPlaying
      return .concatenate(
        .cancel(id: TimerId()),
        environment.audioPlayerClient
          .stop(PlayerId())
          .fireAndForget()
      )
    }

  case let .timerUpdated(time):
    switch memo.mode {
    case .notPlaying:
      break
    case let .playing(progress: progress):
      memo.mode = .playing(progress: time / memo.duration)
    }
    return .none

  case let .titleTextFieldChanged(text):
    memo.title = text
    return .none
  }
}

struct VoiceMemoView: View {
  // NB: We are using an explicit `ObservedObject` for the view store here instead of
  // `WithViewStore` due to a SwiftUI bug where `GeometryReader`s inside `WithViewStore` will
  // not properly update.
  //
  // Feedback filed: https://gist.github.com/mbrandonw/cc5da3d487bcf7c4f21c27019a440d18
  @ObservedObject var viewStore: ViewStore<VoiceMemo, VoiceMemoAction>

  init(store: Store<VoiceMemo, VoiceMemoAction>) {
    self.viewStore = ViewStore(store)
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        if self.viewStore.mode.isPlaying {
          Rectangle()
            .foregroundColor(Color(.systemGray5))
            .frame(width: proxy.size.width * CGFloat(self.viewStore.mode.progress ?? 0))
            .animation(.linear(duration: 0.5))
        }

        HStack {
          TextField(
            "Untitled, \(dateFormatter.string(from: self.viewStore.date))",
            text: self.viewStore.binding(
              get: \.title, send: VoiceMemoAction.titleTextFieldChanged)
          )

          Spacer()

          dateComponentsFormatter.string(from: self.currentTime).map {
            Text($0)
              .font(Font.footnote.monospacedDigit())
              .foregroundColor(Color(.systemGray))
          }

          Button(action: { self.viewStore.send(.playButtonTapped) }) {
            Image(systemName: self.viewStore.mode.isPlaying ? "stop.circle" : "play.circle")
              .font(Font.system(size: 22))
          }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .padding([.leading, .trailing])
      }
    }
    .buttonStyle(BorderlessButtonStyle())
    .listRowBackground(self.viewStore.mode.isPlaying ? Color(.systemGray6) : .clear)
    .listRowInsets(EdgeInsets())
  }

  var currentTime: TimeInterval {
    self.viewStore.mode.progress.map { $0 * self.viewStore.duration } ?? self.viewStore.duration
  }
}
