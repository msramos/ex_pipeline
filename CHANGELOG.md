# Changelog for `ex_pipeline`
## v0.2.0

### New Features
- `Pipeline.State` now tracks the steps that were executed
- Examples were added into some funtions
- Updated docs

### Changes
- Tests are now async
- The `Pipeline.State.invalidate/2` will now add a generic error message into the state.
- Removed `Pipeline.State.callback/3`. Callbacks now handled directly by `Pipeline`.
- Removed `errors` from `Pipeline.State` struct, since we only track the last error anyways.
- The callbacks `__pipeline_steps__` and `__pipeline_callbacks` were merged into a single callback, `__pipeline__`
  that returns a tuple with all the information we need.


## v0.1.0

First version!

### New Features
- Basic pipeline building and state management