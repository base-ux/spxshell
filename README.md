## Static POSIX shell toolkit

This toolkit is intended to build self-sufficient shell scripts.
The idea is to compose such script from some pieces by using some sort of
lightweight 'preprocessor'.

* `spxgen.sht` -- template for preprocessor and script generator
* `mkdeploy.sht` -- template for generator of deploy scripts
* `install.sht` -- template for installation script

The documentation will be written soon, sorry for now.

### Get

```
git clone https://github.com/base-ux/spxshell.git
```

### Build

To build all scripts:

```
./make.sh
```

### Install

Either:

```
./make.sh install
```

or execute `install.sh` (in `out` directory) script after building.

### Create deploy script

To create deploy script:

```
./make.sh deploy
```

This script is self-sufficient for installing the set of all other scripts
on other hosts (just copy and run it).
