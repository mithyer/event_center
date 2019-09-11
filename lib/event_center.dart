import 'dart:async';
import 'dart:collection';

class EventListener<T> {
  final StreamSubscription<T> _subcription;
  final String _id;

  var _cancelled = false;
  bool get cancelled => _cancelled;

  bool operator ==(o) => o is EventListener<T> && o._id == _id;
  int get hashCode => _id.hashCode;

  static int flag = 0;
  EventListener(this._subcription) : _id = "$T-${++flag}";
}

class EventCenter {
  final StreamController streamController;

  /// Creates a custom [EventCenter].
  ///
  /// If [sync] is true, events are passed directly to the stream's listeners
  /// during a [post] call. If false (the default), the event will be passed to
  /// the listeners at a later time, after the code creating the event has
  /// completed.
  EventCenter(bool sync)
      : this.streamController = StreamController.broadcast(sync: sync);

  /// Singleton
  static EventCenter defaultCenter = EventCenter(false);

  final Map<Type, HashSet<EventListener>> _listenersSetMap = {};
  HashSet<EventListener> _getListenersSet<T>() {
    return _listenersSetMap[T] ??
        () {
          final hashSet = HashSet<EventListener>();
          _listenersSetMap[T] = hashSet;
          return hashSet;
        }();
  }

  /// Add listener: each time a new instance will be created
  EventListener<T> addListener<T>(Function(T) onEvent) {
    EventListener<T> listener;
    if (T == dynamic) {
      listener = EventListener(streamController.stream.listen(onEvent));
    } else {
      listener = EventListener(streamController.stream
          .where((event) => event is T)
          .cast<T>()
          .listen(onEvent));
    }
    final lSet = _getListenersSet<T>();
    lSet.add(listener);
    return listener;
  }

  /// Remove [listener].
  void removeListener<T>(EventListener<T> listener) {
    if (listener._cancelled) {
      return;
    }
    final lSet = _listenersSetMap[T];
    if (null == lSet) {
      return;
    }
    if (!lSet.remove(listener)) {
      return;
    }
    listener._subcription.cancel();
    listener._cancelled = true;
  }

  /// Remove the listeners which type is T. if [inherit] is true, the inherit type will be removed too.
  void removeListeners<T>({bool inherit = false}) {
    final lSet = _listenersSetMap[T];
    if (null != lSet) {
      for (var listener in lSet) {
        listener._subcription.cancel();
        listener._cancelled = true;
      }
      _listenersSetMap.remove(T);
    }

    if (inherit) {
      _listenersSetMap.keys.where((type) {
        return type is T;
      }).map((type) {
        return _listenersSetMap[type];
      }).forEach((hashSet) {
        hashSet.forEach((listener) {
          listener._subcription.cancel();
          listener._cancelled = true;
        });
        hashSet.clear();
      });
    }
  }

  /// Remove all listeners
  void removeAllListeners() {
    _listenersSetMap.forEach((type, hashSet) {
      hashSet.forEach((listener) {
        listener._subcription.cancel();
        listener._cancelled = true;
      });
    });
    _listenersSetMap.clear();
  }

  /// Post a new event with the specified [event].
  void post<T>(T event) {
    streamController.add(event);
  }
}
