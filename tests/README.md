# Accessibility monitor verification

## Automated checks

With Xcode, XcodeGen, and CMake installed, run the checks used by continuous integration from the repository root:

```sh
make -C example
make -C example-app
make -C tests
```

The Swift tests simulate an application whose Accessibility interface is activated by an application-role request and whose focus becomes available on a later polling tick.
They verify acquisition order, recovery without a notification, best-effort handling of an unavailable application role, and rejection of invalid focus values.
The retry-state tests verify the finite retry budget, cancellation upon recovery or application loss, and renewed recovery following an application switch or subsequent loss of focus.
Role acquisition tests treat empty and unreadable roles as unavailable, including when a focused AX element already exists.
Polling integration tests verify publication of geometry and available titles during recovery, resumption of lightweight geometry polling, and the inactive and restarted monitor lifecycle.
These tests do not require Accessibility permission or a running browser.

## Chrome startup regression

The monitor requests the application role before querying focus to activate Chrome's native Accessibility interface.
If the focused role remains unavailable during initialisation, acquisition is retried on up to ten subsequent polling ticks at 500 ms intervals, ending upon recovery, an application change, or monitor shutdown.
Recovery performs full snapshots, including geometry and available titles, in place of the lightweight polling checks and therefore incurs additional AX work until recovery ends.
The poll budget and interval define nominal scheduling; AX request latency and task scheduling may extend the elapsed recovery period beyond five seconds.

This procedure requires Google Chrome and an Accessibility-authorised build of the monitor example application.
Use a new Chrome process and profile for each run because another Accessibility client, including Accessibility Inspector, may activate the browser interface before measurement.

1.  Build and launch the monitor with `make -C example-app run`, and grant the example application Accessibility permission if required.
2.  Create a local page and launch a separate Chrome process from a terminal:

    ```sh
    probe_dir="$(mktemp -d)"
    printf '%s\n' '<!doctype html><textarea autofocus>alpha beta gamma</textarea>' > "$probe_dir/focus.html"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
      --user-data-dir="$probe_dir/profile" --no-first-run --no-default-browser-check \
      "file://$probe_dir/focus.html" > "$probe_dir/chrome.log" 2>&1 &
    ```

3.  Keep Chrome frontmost with the textarea focused, without opening Accessibility Inspector or using another AX probe.
4.  Confirm that the example reports the textarea role as `AXTextArea` after initialisation, without an application switch or additional focus change.
5.  Switch to a native text field and back to Chrome, and confirm that focus reporting remains correct.
6.  Close the test Chrome process and remove the temporary profile directory after testing.
