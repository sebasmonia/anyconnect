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

Place anyconnect.el in your load-path. Or (preferred) install from MELPA.

The next step would be to call `customize-group` for anyconnect.

1. **REQUIRED**: Add the location of  `vpncli`:

```elisp
    (setq anyconnect-path "C:\\Program Files (x86)\\Cisco\\Cisco AnyConnect Secure Mobility Client\\vpncli.exe")
```

2. You can set `anyconnect-modeline-indicator` lets you specify if you want to see a "VPN" indicator only when
connected, all the time, or never.

3. By `anyconnect-log-buffer-name` is "*VPN Log*". This buffer shows timestamped package messages and
collects the output of process used to connect, which is very useful to debug


## Connection steps setup

The alist `anyconnect-steps` has the steps of the connection dance. Each element has a function, and a value to pass to it. I guess this means we can support a lot of things, in the most common cases this will look like the default value:
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

A final `\n` is appended to the last step.

The simplest way to figure out the steps is to make a manual call to `vpncli` and note the steps required. On each connection attemp, the ouput of the process will be logged for easy debugging.
Another example of `anyconnect-steps`:
```elisp
 '((identity . "GroupA")
   (identity . "sebasmonia")
   (read-passwd . "Password: ")
   (identity . "y"))
```

These steps would connect to GroupA, use a fixed username, prompt for a single password, and accept the connection banner.

# Usage

`M-x anyconnect-connect`. You will get messages for each step.

`M-x anyconnect-state`. Will show you whether you are `'connected` or `'disconnected`. Use prefix arg to invoke `vpncli` instead of relying on the internal state, in case you had a network hiccup, etc.


