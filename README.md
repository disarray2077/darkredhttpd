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

## How to run darkredhttpd

Serve /var/www/htdocs on the default port (80 if running as root, else 8080):

```
./darkredhttpd /var/www/htdocs
```

Serve `~/public_html` on port 8081:

```
./darkredhttpd ~/public_html --port 8081
```

Only bind to one IP address (useful on multi-homed systems):

```
./darkredhttpd ~/public_html --addr 192.168.0.1
```

Serve at most 4 simultaneous connections:

```
./darkredhttpd ~/public_html --maxconn 4
```

Log accesses to a file:

```
./darkredhttpd ~/public_html --log access.log
```

Commandline options can be combined:

```
./darkredhttpd ~/public_html --port 8080 --addr 127.0.0.1
```

To see a full list of commandline options,
run darkredhttpd without any arguments:

```
./darkredhttpd
```