# anyconnect
Wrapper for "vpncli". Connect to your VPN from Emacs!

This is a wrapper over the `vpncli` command line tool from Cisco AnyConnect. I bet most Linux users have a nice bash
wrapper around it, but if they didn't, or if they work in a Windows environment like I do, this little package skips
one trip to the mouse. Plus, mode line indicator :)

## Table of contents

<!--ts-->

   * [Installation and configuration](#installation-and-configuration)
   * [Connection steps setup](#connection-steps-setup)
   * [Usage](#usage)

<!--te-->

## Installation and configuration

Place `anyconnect.el` in your load-path, and `(require 'anyconnect)`. The package is not in MELPA yet, not sure of the wide audience appeal for this.

The next step would be to call `customize-group` for anyconnect.

1. Add the location of vpncli.exe in `anyconnect-path`. Defaults to `"C:\\Program Files (x86)\\Cisco\\Cisco AnyConnect Secure Mobility Client\\vpncli.exe"`

2. You can set `anyconnect-modeline-indicator` to specify if you want to see a "VPN" indicator only when
connected, all the time, or never. The default is `'connected`.

3. By default `anyconnect-log-buffer-name` is `*VPN Log*`. This buffer shows timestamped package messages and
collects the output of process used to connect, which is very useful to debug

## Connection steps setup

Last piece to customize is the alist `anyconnect-steps`, which has the steps to the connection dance. Each element has a function, and a value to pass to it. In the most common cases this will look like the default value:
```elisp
 '((identity . "\n")
   (read-string . "Username: ")
   (read-passwd . "Password: ")
   (read-passwd . "Second password: ")
   (identity . "y"))
```

The above will:

1. Send an empty newline, which would accept the default group.
2. Prompt for a clear text username.
3. Prompt for a password.
4. Prompt for a second password, which is usually a 2FA code
5. Send a literal 'y" to accept after the connection banner

NOTE: A final `\n` is appended to the last step automatically.

The simplest way to figure out the right value for you is to make a manual call to `vpncli` and note the steps required. On each connection attempt, the ouput of the process will be logged for easy debugging.
Another example of `anyconnect-steps`:
```elisp
 '((identity . "\n1")
   (identity . "sebasmonia")
   (read-passwd . "Password: ")
   (identity . "y"))
```

These steps would connect to the group "1" in the on-screen menu, use a fixed username, prompt for a single password, and accept the connection banner.

# Usage

## Commands

`M-x`...

- `anyconnect-connect`: You will go through you configured steps, get a message for connection success/failure.

- `anyconnect-status`: Will show you the current VPN status, and if needed refresh the mode line. Use prefix arg to invoke `vpncli` instead of relying on the internal state, in case you had a network hiccup, etc.

- `anyconnect-disconnect`: to...disconnect.

- `anyconnect-abort`: if after you try connecting the process seems stuck, this will send the vpncli output to the log buffer, and close the process.


## Other functions

- `anyconnect-connected-p`: As expected, returns `t` if you are connected to the VPN. Call with a true argument to invoke `vpncli` instead of returning the package state.

- `anyconnect-connect`: You can add to your bindings `(anyconnect-connect "Host Name" "ConnName")` to skip the host name selection menu, and jump straight to the connection steps. The optional "ConnName" lets you specify a custom string to display in the mode line (either "ConnName" or "VPN:ConnName"), in case you have different configurations.
