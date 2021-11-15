# darkredhttpd

A version of [darkhttpd](https://github.com/emikulic/darkhttpd) for BeefLang.

Features:

* Almost every feature of [darkhttpd](https://github.com/emikulic/darkhttpd), features not implemented are left as TODO.
* Works on Windows and Linux, and should also work on others operating systems that Beef supports (But some code changes may be necessary).
* Can throttle the upload speed with the argument `--throttle`

Security:

* Almost every security feature of [darkhttpd](https://github.com/emikulic/darkhttpd), features not implemented are left as TODO.
* Rate-limited authentication

Limitations:

* Only serves static content - no CGI.

## How to build darkredhttpd

To build darkredhttpd you need to have the BeefLang compiler, if you're on Windows you can download it [here](https://www.beeflang.org/#releases), for any other operating system it's necessary to build from source, you can find BeefLang repository [here](https://github.com/beefytech/Beef).

## How to run darkredhttpd

Serve /var/www/htdocs on the default port (80 if running as root, else 8080):

```
./darkhttpd /var/www/htdocs
```

Serve `~/public_html` on port 8081:

```
./darkhttpd ~/public_html --port 8081
```

Only bind to one IP address (useful on multi-homed systems):

```
./darkhttpd ~/public_html --addr 192.168.0.1
```

Serve at most 4 simultaneous connections:

```
./darkhttpd ~/public_html --maxconn 4
```

Log accesses to a file:

```
./darkhttpd ~/public_html --log access.log
```

Chroot for extra security (you need root privs for chroot):

```
./darkhttpd /var/www/htdocs --chroot
```

Use default.htm instead of index.html:

```
./darkhttpd /var/www/htdocs --index default.htm
```

Add mimetypes - in this case, serve .dat files as text/plain:

```
$ cat extramime
text/plain  dat
$ ./darkhttpd /var/www/htdocs --mimetypes extramime
```

Drop privileges:

```
./darkhttpd /var/www/htdocs --uid www --gid www
```

Use acceptfilter (FreeBSD only):

```
kldload accf_http
./darkhttpd /var/www/htdocs --accf
```

Run in the background and create a pidfile:

```
./darkhttpd /var/www/htdocs --pidfile /var/run/httpd.pid --daemon
```

Web forward (301) requests for some hosts:

```
./darkhttpd /var/www/htdocs --forward example.com http://www.example.com \
  --forward secure.example.com https://www.example.com/secure
```

Web forward (301) requests for all hosts:

```
./darkhttpd /var/www/htdocs --forward example.com http://www.example.com \
  --forward-all http://catchall.example.com
```

Commandline options can be combined:

```
./darkhttpd ~/public_html --port 8080 --addr 127.0.0.1
```

To see a full list of commandline options,
run darkhttpd without any arguments:

```
./darkhttpd
```

## How to run darkhttpd in Docker

First, build the image.
```
docker build -t darkhttpd .
```
Then run using volumes for the served files and port mapping for access.

For example, the following would serve files from the current user's dev/mywebsite directory on http://localhost:8080/
```
docker run -p 8080:80 -v ~/dev/mywebsite:/var/www/htdocs:ro darkhttpd
```