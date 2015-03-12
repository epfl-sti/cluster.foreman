GNU Screen is a software application that can be used to multiplex several virtual consoles, allowing a user to access multiple separate terminal sessions inside a single terminal window or remote terminal session. It is useful for dealing with multiple programs from a command line interface, and for separating programs from the Unix shell that started the program.
(source http://en.wikipedia.org/wiki/GNU_Screen)

## Installation
* Debian: ```apt-get install screen```
* RedHat: ```yum install screen```

## Screen Sharing
1. Launch a specific screen: ```screen -d -m -S shared```
2. Other host/tty can connect to the same screen with: ```screen -x shared```

## Useful commands
* List screen: ```screen ls```
* ...



## Reference
* [screen quick reference](http://aperiodic.net/screen/quick_reference)