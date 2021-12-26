import tables, sets
type
  Transition*[S] = tuple[fromS, toS: S]
  TransitionCb*[S] = proc (fsm: Fsm[S], fromS, toS: S)  #{.closure, gcsafe.}
  TransitionLeaveCb*[S] = proc (fsm: Fsm[S], fromS: S)  #{.closure, gcsafe.}
  TransitionEnterCb*[S] = proc (fsm: Fsm[S], toS: S)  #{.closure, gcsafe.}
  Fsm*[S] = ref object
    state: S
    transitions: Table[Transition[S], TransitionCb[S]]
    leaveTransitions: Table[S, TransitionLeaveCb[S]]
    enterTransitions: Table[S, TransitionEnterCb[S]]
    allowedTransitions: HashSet[Transition[S]]
    limitTransitions: bool

proc newFsm*[S](initState: S, limitTransitions = true): Fsm[S] =
  ## If `limitTransitions` is true one must define all allowed transitions
  result = Fsm[S]()
  result.state = initState
  result.limitTransitions = limitTransitions

proc getAllowedTransitions*[S](fsm: Fsm[S]): seq[Transition[S]] =
  for trans in fsm.allowedTransitions:
    result.add trans

proc allowTransition*[S](fsm: Fsm[S], trans: Transition[S], bidirectional = true) =
  fsm.allowedTransitions.incl(trans)
  if bidirectional:
    fsm.allowedTransitions.incl((trans.toS, trans.fromS))



proc allowTransition*[S](fsm: Fsm[S], fromS, toS: S, bidirectional = true) =
  fsm.allowTransition((fromS, toS), bidirectional)

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
  ## This also registers the transition with `allowTransition` so that is does not have to be explicitly allowed.
  fsm.transitions[(fromS, toS)] = cb
  fsm.allowTransition((fromS, toS), bidirectional = false) # allow only the defined direction!

proc transition*[S](fsm: Fsm[S], toS: S) =
  ## Transitions between states.
  ## It calls cb's in this order:
  ##  1. The leave state cb (if exists)
  ##  2. The fromS -> toS cb (if exists)
  ##  3. The enter state cb (if exists)
  if fsm.state == toS:
    echo "Already on ", toS, " no transition"
    return
  let key = (fsm.state, toS).Transition
  if fsm.limitTransitions:
    if not fsm.allowedTransitions.contains(key):
      raise newException(ValueError, "transition not valid:" & $key)
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

  fsm.allowTransition(Start, Map)

  proc transLeaveMap[S](fsm: Fsm[S], fromS: S) = #{.gcsafe.} =
    echo "Leave:", fromS
  fsm.registerLeaveTransition(Map, transLeaveMap[DemoStates])

  proc transMapToMain[S](fsm: Fsm[S], fromS, toS: S) = #{.gcsafe.} =
    echo "Transition from:", fromS, toS, "Cleanup map remove entities etc", obj
  fsm.registerTransition(Map, MainMenu, transMapToMain[DemoStates])

  proc transEnterMainMenu[S](fsm: Fsm[S], toS: S) = #{.gcsafe.} =
    echo "Enter:", toS
  fsm.registerEnterTransition(MainMenu, transEnterMainMenu[DemoStates])

  # Run
  fsm.transition(Map)
  fsm.transition(MainMenu)

  echo fsm.getAllowedTransitions()
