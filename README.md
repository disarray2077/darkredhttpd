# darkredhttpd

A version of [darkhttpd](https://github.com/emikulic/darkhttpd) for BeefLang.

Features:

* Almost every feature of [darkhttpd](https://github.com/emikulic/darkhttpd), features not implemented were left as TODO.
* Works on Windows and Linux, and should also work on others operating systems that Beef supports (But some code changes may be necessary).
* Can throttle the upload speed with the argument `--throttle`

Security:

* Almost every security feature of [darkhttpd](https://github.com/emikulic/darkhttpd), features not implemented were left as TODO.
* Rate-limited authentication

Limitations:

* Only serves static content - no CGI.

## How to build darkredhttpd

To build darkredhttpd you need to have the BeefLang compiler, if you're on Windows you can download it [here](https://www.beeflang.org/#releases), for any other operating system it's necessary to build from source, you can find BeefLang repository [here](https://github.com/beefytech/Beef).
