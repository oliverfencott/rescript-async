open Zora

let sleep = (duration, fn) => Js.Global.setTimeout(fn, duration)->ignore
let sleepAsync = duration => duration->sleep->Async.make
let sleepPromise = duration => {
  Promise.make((resolve, _) => {
    let unit = ()
    sleep(duration, () => resolve(. unit))
  })
}

zora("should run as callback", t => {
  let init = ref(false)

  Promise.all([
    Promise.make((resolve, _reject) => {
      sleepAsync(1000)->Async.run(() => {
        resolve(. init.contents = true)
      })
    }),
    sleepPromise(500)->then(_ => {
      t->is(init.contents, false, "async is still running")

      done()
    }),
    sleepPromise(1500)->then(_ => {
      t->is(init.contents, true, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("should run as promises", t => {
  let init = ref(false)

  Promise.all([
    Promise.make((resolve, _reject) => {
      sleepAsync(1000)->Async.toPromise->Js.Promise.then_(_ => {
        resolve(. init.contents = true)

        Js.Promise.resolve()
      }, _)->ignore
    }),
    sleepPromise(500)->then(_ => {
      t->is(init.contents, false, "async is still running")

      done()
    }),
    sleepPromise(1500)->then(_ => {
      t->is(init.contents, true, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("should map values", t => {
  let init = ref(false)
  let effect = sleepAsync(1000)->Async.map(_ => true)

  Promise.all([
    Promise.make((resolve, _reject) => {
      effect->Async.run(p => {
        resolve(. init.contents = p)
      })
    }),
    sleepPromise(500)->then(_ => {
      t->ok(!init.contents, "async is still running")

      done()
    }),
    sleepPromise(1500)->then(_ => {
      t->ok(init.contents, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("should flatMap values", t => {
  let init = ref(false)
  let effect = {
    sleepAsync(1000)->Async.flatMap(_ => sleepAsync(1000))
  }

  Promise.all([
    Promise.make((resolve, _reject) => {
      effect->Async.run(_ => {
        resolve(. init.contents = true)
      })
    }),
    sleepPromise(500)->then(_ => {
      t->ok(!init.contents, "async is still running")

      done()
    }),
    sleepPromise(2500)->then(_ => {
      t->ok(init.contents, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("should join values", t => {
  let init = ref(false)
  let effect = {
    sleepAsync(1000)->Async.map(_ => Async.unit())->Async.join
  }

  Promise.all([
    Promise.make((resolve, _reject) => {
      effect->Async.run(_ => {
        resolve(. init.contents = true)
      })
    }),
    sleepPromise(500)->then(_ => {
      t->ok(!init.contents, "async is still running")

      done()
    }),
    sleepPromise(2500)->then(_ => {
      t->ok(init.contents, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("should map, flatMap, join and run", t => {
  let init = ref(false)

  let effect =
    Async.unit()
    ->Async.flatMap(_ => sleepAsync(1000))
    ->Async.map(_ => true)
    ->Async.flatMap(x => sleepAsync(1000)->Async.map(_ => x))
    ->Async.map(Async.unit)
    ->Async.join

  Promise.all([
    Promise.make((resolve, _reject) => {
      effect->Async.run(x => {
        resolve(. init.contents = x)
      })
    }),
    sleepPromise(500)->then(_ => {
      t->ok(!init.contents, "async is still running")

      done()
    }),
    sleepPromise(1000)->then(_ => {
      t->ok(!init.contents, "async is still running")

      done()
    }),
    sleepPromise(2500)->then(_ => {
      t->ok(init.contents, "async finished running")

      done()
    }),
  ])->then(_ => done())
})

zora("Cancellable", t => {
  let effect =
    Async.unit()
    ->Async.flatMap(_ => sleepAsync(1000))
    ->Async.map(_ => true)
    ->Async.flatMap(x => sleepAsync(1000)->Async.map(_ => x))
    ->Async.map(Async.unit)
    ->Async.join

  t->test("should run when not cancelled", t => {
    let init = ref(false)

    Promise.all([
      Promise.make((resolve, _) => {
        let _ = effect->Async.Cancellable.run(x => {
          init.contents = x

          let unit = ()
          resolve(. unit)
        })
      }),
      sleepPromise(500)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(1000)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(2500)->then(_ => {
        t->ok(init.contents, "async finished running")

        done()
      }),
    ])->then(_ => done())
  })

  t->test("should not run when not cancelled", t => {
    let init = ref(false)
    let cancel = effect->Async.Cancellable.run(x => {
      init.contents = x
    })

    Promise.all([
      sleepPromise(1500)->then(_ => {
        cancel()
        done()
      }),
      sleepPromise(500)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(1000)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(2500)->then(_ => {
        t->ok(!init.contents, "async finished running")

        done()
      }),
    ])->then(_ => done())
  })

  t->test("should run when cancelled after completion", t => {
    let init = ref(false)

    let cancel = effect->Async.Cancellable.run(x => {
      init.contents = x
    })

    Promise.all([
      sleepPromise(3500)->then(_ => {
        cancel()
        done()
      }),
      sleepPromise(500)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(1000)->then(_ => {
        t->ok(!init.contents, "async is still running")

        done()
      }),
      sleepPromise(2500)->then(_ => {
        t->ok(init.contents, "async finished running")

        done()
      }),
    ])->then(_ => done())
  })

  done()
})
