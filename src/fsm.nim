import tables
type
  Transition*[S] = tuple[fromS, toS: S]
  TransitionCb*[S] = proc (fsm: Fsm[S], fromS, toS: S) {.closure, gcsafe.}
  TransitionLeaveCb*[S] = proc (fsm: Fsm[S], fromS: S) {.closure, gcsafe.}
  TransitionEnterCb*[S] = proc (fsm: Fsm[S], toS: S) {.closure, gcsafe.}
  Fsm*[S] = ref object
    state: S
    transitions: Table[Transition[S], TransitionCb[S]]
    leaveTransitions: Table[S, TransitionLeaveCb[S]]
    enterTransitions: Table[S, TransitionEnterCb[S]]

proc newFsm*[S](initState: S): Fsm[S] =
  result = Fsm[S]()
  result.state = initState

proc state*[S](fsm: Fsm[S]): S =
  ## Getter for state, changing the state is only allowed via `transition()`
  return fsm.state

proc registerLeaveTransition*[S](fsm: Fsm[S], fromS: S, cb: TransitionLeaveCb[S]) =
  ## Registers a callback that is called when leaving a state
  fsm.leaveTransitions[fromS] = cb

proc registerEnterTransition*[S](fsm: Fsm[S], toS: S, cb: TransitionEnterCb[S]) =
  ## Registers a callback that is called when entering a state
  fsm.enterTransitions[toS] = cb

proc registerTransition*[S](fsm: Fsm[S], fromS, toS: S, cb: TransitionCb[S]) =
  ## Registers a callback that is called when transitioning from ´fromS´ to `toS`.
  ## But only then.
  fsm.transitions[(fromS, toS)] = cb

proc transition[S](fsm: Fsm[S], toS: S) =
  ## Transitions between states.
  ## It calls cb's in this order:
  ##  1. The leave state cb (if exists)
  ##  2. The fromS -> toS cb (if exists)
  ##  3. The enter state cb (if exists)
  let key = (fsm.state, toS).Transition
  if fsm.leaveTransitions.hasKey(fsm.state):
    let cb = fsm.leaveTransitions[fsm.state]
    cb(fsm, fsm.state)
  if fsm.transitions.hasKey(key):
    echo "Call transition"
    let cb = fsm.transitions[key]
    cb(fsm, fsm.state, toS)
  if fsm.enterTransitions.hasKey(toS):
    let cb = fsm.enterTransitions[toS]
    cb(fsm, toS)
  fsm.state = toS
  echo fsm.state


when isMainModule:
  import print
  type DemoStates = enum
    Start
    MainMenu
    Map

  type Obj = object
    ss: string

  var obj = Obj()
  obj.ss = "faa"

  var fsm = newFsm[DemoStates](Start)
  proc transLeaveMap[S](fsm: Fsm[S], fromS: S) {.gcsafe.} =
    echo "Leave:", fromS
  fsm.registerLeaveTransition(Map, transLeaveMap[DemoStates])

  proc transMapToMain[S](fsm: Fsm[S], fromS, toS: S) {.gcsafe.} =
    echo "Transition from:", fromS, toS, "Cleanup map remove entities etc", obj
  fsm.registerTransition(Map, MainMenu, transMapToMain[DemoStates])

  proc transEnterMainMenu[S](fsm: Fsm[S], toS: S) {.gcsafe.} =
    echo "Enter:", toS
  fsm.registerEnterTransition(MainMenu, transEnterMainMenu[DemoStates])

  # Run
  fsm.transition(Map)
  fsm.transition(MainMenu)

